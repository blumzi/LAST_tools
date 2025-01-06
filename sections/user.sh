#!/bin/bash

module_include lib/message
module_include lib/util
module_include lib/user
module_include lib/sections
module_include lib/container


export -a user_expected_groups=( sudo dialout )
export user_expected_groups_list
user_expected_groups_list="$(IFS=,; echo "${user_expected_groups[*]}")"

sections_register_section "user" "Manages the \"${user_name}\" user"

function user_enforce() {
    if grep "^${user_name}:" /etc/passwd >/dev/null; then

        # the user exists
        message_success "User ${user_name} exists"

        # make sure the user belongs to the expected groups
        local expected found
        local -a missing
        read -r -a groups <<< "$( groups ${user_name} 2>/dev/null | sed -e 's;^.*:.;;' )"
        for expected in "${user_expected_groups[@]}"; do
            found=false
            for g in "${groups[@]}"; do
                if [ "${g}" = "${expected}" ]; then
                    found=true
                    break
                fi
            done
            if ! ${found}; then
                missing+=( "${expected}" )
            fi
        done
        if (( ${#missing[*]} != 0 )); then
            message_info "Making \"${user_name}\" a member of the groups: ${user_expected_groups_list}"
            usermod -G "${user_expected_groups_list}" ${user_name}
		else
			message_success "User ${user_name} is a member of groups: ${user_expected_groups_list}"
        fi
    else
        # the user does not exist, make it
        message_info "Creating user \"${user_name}\" ..."
        useradd -m -G "${user_expected_groups_list}" ${user_name}
    fi

    # enforce the user's home to /home/ocs
    local current_home="$(awk -F: '{print $6}' <<< $(grep "^${user_name}:" /etc/passwd))"
	if [ "${current_home}" = "${user_home}" ]; then
		message_success "The user's home is \"${user_home}\"."
	else
		sed -i "s;${current_home}:;${user_home}:;" /etc/passwd
		mv "${current_home}" "${user_home}"
        rmdir "$(dirname "${current_home}")"
		message_success "Changed the user's home from \"${current_home}\" to \"${user_home}\"."
	fi

    # make sure the user owns it's home
    chown --recursive ${user_name}.${user_group} "${user_home}"
    message_success "Changed ownership (recursively) of ${user_home} to ${user_name}.${user_group}"

    # add the HTTP proxy incantations to the .bash_profile
	local bash_profile
	bash_profile="${user_home}/.bash_profile"
	if [ ! -r "${bash_profile}" ] || [ "$( grep -E -c '(source /etc/profile.d/last.sh|module_include lib/util|util_test_and_set_http_proxy|unset TMOUT|source)' "${bash_profile}" )" != 5 ]; then
		local tmp
		tmp=$(mktemp)
		{
			echo "source /etc/profile.d/last.sh"
			echo "module_include lib/util"
            echo "util_test_and_set_http_proxy"
			echo "unset TMOUT"
            echo ""
            echo "if [ -r ~/.bash_aliases ]; then"
            echo "  source ~/.bash_aliases"
            echo "fi"
		} > "${tmp}"
		install -D --mode 644 --owner "${user_name}" --group "${user_group}" "${tmp}" "${bash_profile}"
		rm -f "${tmp}"

		message_success "Regenerated ${bash_profile}"
    else
        message_success "${bash_profile} complies"
    fi

    # shellcheck disable=SC1090
    source "${bash_profile}"

    # take care of ~/matlab
    if [ -d "${user_matlabdir}" ]; then
        message_success "The directory \"${user_matlabdir}\" exists"
    else
        mkdir -p "${user_matlabdir}"
        chown ${user_name}.${user_group} "${user_matlabdir}"
        message_success "Created the \"${user_matlabdir}\" directory."
    fi

    user_enforce_mozilla_proxy
    user_enforce_pulseaudio    
    util_enforce_shortcut --override --favorite google-chrome
    user_enforce_git_config
    user_enforce_astropack

    local bash_aliases
    bash_aliases="$(module_locate files/root/home/ocs/.bash_aliases)"
    if  [ -r "${bash_aliases}" ]; then
        cp "${bash_aliases}" "${user_home}"
        chown ${user_name}.${user_group} "${user_home}/$(basename "${bash_aliases}")"
        ln -sf ${user_home}/.bash_aliases ~root
    fi

    user_enforce_slack
    user_make_bash_aliases_in_bashrc
}

function user_check() {
    local ret=0
    local -a groups

    # does the user exist?
    if grep "^${user_name}:" /etc/passwd >/dev/null; then
        message_success "User \"${user_name}\" exists"
    else
        message_failure "User \"${user_name}\" does not exit"
        (( ret++ ))
    fi

    # does the user belong to the expected groups
    local found expected
    local -a missing
    read -r -a groups <<< "$( groups ${user_name} 2>/dev/null | sed -e 's;^.*:.;;' )"
    for expected in "${user_expected_groups[@]}"; do
        found=false
        for g in "${groups[@]}"; do
            if [ "${g}" = "${expected}" ]; then
                found=true
                break
            fi
        done
        if ! ${found}; then
            missing+=( "${expected}" )
        fi
    done

    if (( ${#missing[*]} == 0 )); then
        message_success "User \"${user_name}\" is a member of groups: ${user_expected_groups_list}"
    else
        message_failure "User \"${user_name}\" is not a member of the group(s): $(IFS=,; echo "${missing[*]}")"
        (( ret++ ))
    fi
    
    local current_home="$(awk -F: '{print $6}' <<< $(grep "^${user_name}:" /etc/passwd))"
    # is the user's home where we expect it to be?
	if [ "${current_home}" = "${user_home}" ]; then
		message_success "The user's home is \"${user_home}\"."
	else
		message_failure "The user's home is NOT \"${user_home}\" (it is \"${current_home}\")."
	fi

    # does the user's .bash_profile include the code that sets the WIS http proxy?
    local rcfile
    rcfile="${user_home}/.bash_profile"
	if [ -r "${rcfile}" ]; then
		if [ "$( grep -E -c '(source /etc/profile.d/last.sh|module_include lib/util|util_test_and_set_http_proxy|unset TMOUT)' "${rcfile}" )" = 4 ]; then
			message_success "${rcfile} complies"
		else
			message_failure "${rcfile} does not have all the required code"
			(( ret++ ))
		fi
	else
		message_failure "Missing \"${rcfile}\""
		(( ret++ ))
	fi

    # does the user have a ~/matlab directory?
    if [ -d "${user_matlabdir}" ]; then
		message_success "The directory \"${user_matlabdir}\" exists"
    else
		message_failure "The directory \"${user_matlabdir}\" is missing"
    fi

    user_check_mozilla_proxy;                       (( ret += ${?} ))
    user_check_pulseaudio;                          (( ret += ${?} ))
    util_check_shortcut --favorite google-chrome;   (( ret += ${?} ))
    user_check_git_config;                          (( ret += ${?} ))
    user_check_astropack;                           (( ret += ${?} ))
    user_check_slack;                               (( ret += ${?} ))
    user_check_bash_aliases_in_bashrc;              (( ret += ${?} ))

    return $(( ret ))
}

function user_check_mozilla_proxy() {
    local errors=0
    local user_js_file
    eval user_js_file="${user_home}/.mozilla/firefox/*.default/user.js"

    if [ ! -r "${user_js_file}" ]; then
        message_failure "The Mozilla user.js file is missing"
        return 1
    else
        message_success "The Mozilla user.js file exists."
    fi

    if (( $(grep -c -E 'user_pref\("network\.proxy\.(type|HTTP|HTTPS)"' "${user_js_file}") == 3 )); then
        message_success "The Mozilla user.js file has entries for network.proxy.(type|HTTP|HTTPS)"
    else
        message_failure "The Mozilla user.js file does not have entries for network.proxy.(type|HTTP|HTTPS)"
        (( errors++ ))
    fi

    return $(( errors ))
}

function user_enforce_mozilla_proxy() {
    local user_js_file
    eval user_js_file=~"${user_name}/.mozilla/firefox/*.default/user.js"
    mkdir -p "$(dirname "${user_js_file}" )"

    {
        echo '// Weizmann proxy settings'
        echo 'user_pref("network.proxy.type", "1");'
        echo 'user_pref("network.proxy.HTTP", "http://bcproxy.weizmann.ac.il:8080");'
        echo 'user_pref("network.proxy.HTTPS", "http://bcproxy.weizmann.ac.il:8080");'
    } > "${user_js_file}"
}

function user_enforce_pulseaudio() {
    local config_file="${user_home}/.config/pulse/default.pa"

    mkdir -p "$(dirname "${config_file}")"
    echo "load-module module-loopback latency_msec=1" > "${config_file}"
    message_success "pulseaudio: added load module-loopback (${config_file})"
}

function user_check_pulseaudio() {
    local config_file="${user_home}/.config/pulse/default.pa"

    if grep -q "load-module module-loopback latency_msec=1" "${config_file}" 2>/dev/null ; then
        message_success "pulseaudio: module-loopback is loaded by \"${config_file}\""
        return 0
    else
        message_failure "pulseaudio: module-loopback is NOT loaded by \"${config_file}\""
        return 1
    fi
}

function user_enforce_chrome() {
    util_enforce_shortcut --override --favorite google-chrome
}

function user_enforce_git_config() {

    git config --file ${user_git_global_config_file} user.name "${user_git_user_name}"
    git config --file ${user_git_global_config_file} user.email "${user_git_user_email}"    # dummy
    chown ${user_name}.${user_name} ${user_git_global_config_file}

    message_success "git-config: Set dummy user name and email in \"${user_git_global_config_file}\""
}

function user_check_git_config() {
    local ret=0

    local user_name="$(git config --file ${user_git_global_config_file} user.name)"
    local user_email="$(git config --file ${user_git_global_config_file} user.email)"

    if [ "${user_name}" = "${user_git_user_name}" ]; then
        message_success "git-config: The user name is set to \"${user_name}\" (in ${user_git_global_config_file})"
    else
        message_failure "git-config: The user name is set to \"${user_name}\" instead of \"${user_git_user_name}\" (in ${user_git_global_config_file})"
        (( ret++ ))
    fi

    if [ "${user_email}" = "${user_git_user_email}" ]; then
        message_success "git-config: The user email is set to \"${user_email}\" (in ${user_git_global_config_file})"
    else
        message_failure "git-config: The user email is set to \"${user_email}\" instead of \"${user_git_user_email}\" (in ${user_git_global_config_file})"
        (( ret++ ))
    fi

    return $(( ret ))
}

function user_enforce_astropack() {
    local file=${user_home}/.astropack/Passwords.yml

    mkdir -p $(dirname ${file})
    echo "last_operational : ['postgres', 'postgres', '', '']" > ${file}
    chown ${user_name}.${user_group} $(dirname ${file})
    message_success "astropack-passwords: Created ${file}"
}

function user_check_astropack() {
    local file=${user_home}/.astropack/Passwords.yml

    if [ -r ${file} ]; then
        message_success "astropack-passwords: ${file} is readable"
	    if grep -q '^last_operational' ${file} >/dev/null 2>&1; then
		message_success "astropack-passwords: ${file} has line for 'last_operational'"
	    else
		message_failure "astropack-passwords: ${file} does not have a line for 'last_operational'"
	    fi
    else
        message_failure "astropack-passwords: ${file} is missing"
    fi
}

function user_enforce_slack() {
    local tmp=$(mktemp)
    local file=/home/ocs/.bash_aliases

    {
        grep -iv slack ${file}
        echo ''
        cat $(container_path)/files/slack/env
    } > ${tmp}
    cp ${tmp} ${file}
    /bin/rm -f ${tmp}
    message_success "Added slack stuff to ${file}"
}

function user_check_slack() {
    local file=/home/ocs/.bash_aliases
    local nlines=$(grep -ic slack ${file})

    if [ ${nlines} = 3 ]; then
        message_success "${file} has three slack lines"
    else
        message_failure "${file} has ${nlines} slack lines (instead of 3)"
    fi
}

function user_check_bash_aliases_in_bashrc() {
    local line="[ -r ~/.bash_aliases ] && . ~/.bash_aliases"

    if grep -q "${line}" ~ocs/.bashrc; then
        message_success "~ocs/.bashrc is configured to source ~ocs/.bash_aliases"
        return 0
    else
        message_failure "~ocs/.bashrc is not configured to source ~ocs/.bash_aliases"
        return 1
    fi
}

function user_make_bash_aliases_in_bashrc() {
    local line="[ -r ~/.bash_aliases ] && . ~/.bash_aliases"

    if ! grep -q "${line}" ~ocs/.bashrc; then
        echo "${line}" >> ~ocs/.bashrc
        message_success "Added sourcing of .bash_aliases to ~ocs/.bashrc"
    fi
}

function user_policy() {
    cat <<- EOF

    All the LAST processes and resources are owned by the user "${user_name}"

    - The user must exist and be a member of the sudo and dialout groups
    - The user's home directory should be ${user_home}
    - The directory ${user_home}}/matlab must exist
    - The file ${user_home}/.bash_profile should contain code for:
     - using the Weizmann Institute's HTTP(s) proxies
     - unsetting the bash TMOUT variable, so that sessions will not time out
    
EOF
}
