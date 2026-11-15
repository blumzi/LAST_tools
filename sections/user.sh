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

#
# Firefox proxy prefs (manual proxy, bypassed for the LAST LAN)
#
user_mozilla_proxy_prefs=(
    'user_pref("network.proxy.type", 1);'
    'user_pref("network.proxy.http", "bcproxy.weizmann.ac.il");'
    'user_pref("network.proxy.http_port", 8080);'
    'user_pref("network.proxy.ssl", "bcproxy.weizmann.ac.il");'
    'user_pref("network.proxy.ssl_port", 8080);'
    'user_pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, 10.23.0.0/16");'
)

#
# Prints the user's Firefox profile directories (one per line), as listed in profiles.ini
#
function user_mozilla_profile_dirs() {
    local top is_relative path

    for top in "${user_home}/.mozilla/firefox" "${user_home}/snap/firefox/common/.mozilla/firefox"; do
        [ -r "${top}/profiles.ini" ] || continue
        awk -F= '
            /^\[/                           { if (p != "") print r "\t" p; p = ""; r = 1; inprof = ($0 ~ /^\[Profile/); next }
            inprof && $1 == "Path"          { p = substr($0, 6) }
            inprof && $1 == "IsRelative"    { r = $2 }
            END                             { if (p != "") print r "\t" p }
        ' "${top}/profiles.ini" | while IFS=$'\t' read -r is_relative path; do
            if [ "${is_relative}" = 1 ]; then
                path="${top}/${path}"
            fi
            [ -d "${path}" ] && echo "${path}"
        done
    done
}

function user_check_mozilla_proxy() {
    local errors=0
    local profile_dir user_js_file pref missing
    local -a profile_dirs

    mapfile -t profile_dirs < <(user_mozilla_profile_dirs)
    if (( ${#profile_dirs[*]} == 0 )); then
        message_warning "No Firefox profiles found for ${user_name} (Firefox never ran?), cannot check proxy settings"
        return 0
    fi

    for profile_dir in "${profile_dirs[@]}"; do
        user_js_file="${profile_dir}/user.js"
        if [ ! -r "${user_js_file}" ]; then
            message_failure "The Mozilla file \"${user_js_file}\" is missing"
            (( errors++ ))
            continue
        fi

        missing=0
        for pref in "${user_mozilla_proxy_prefs[@]}"; do
            grep -Fxq "${pref}" "${user_js_file}" || (( missing++ ))
        done

        if (( missing == 0 )); then
            message_success "The Mozilla file \"${user_js_file}\" has the proxy settings"
        else
            message_failure "The Mozilla file \"${user_js_file}\" misses ${missing} of ${#user_mozilla_proxy_prefs[*]} proxy settings"
            (( errors++ ))
        fi
    done

    return $(( errors ))
}

function user_enforce_mozilla_proxy() {
    local profile_dir user_js_file tmp
    local stale_dir="${user_home}/.mozilla/firefox/*.default"
    local -a profile_dirs

    # A previous version of this function created a directory literally named '*.default'
    if [ -d "${stale_dir}" ] && [ "$(ls -A "${stale_dir}")" = user.js ]; then
        /bin/rm -f "${stale_dir}/user.js"
        rmdir "${stale_dir}" && message_success "Removed the stale directory \"${stale_dir}\""
    fi

    mapfile -t profile_dirs < <(user_mozilla_profile_dirs)
    if (( ${#profile_dirs[*]} == 0 )); then
        message_warning "No Firefox profiles found for ${user_name} (Firefox never ran?), cannot set proxy settings"
        return 0
    fi

    for profile_dir in "${profile_dirs[@]}"; do
        user_js_file="${profile_dir}/user.js"
        tmp="$(mktemp)"
        {
            # keep any non-proxy prefs already in user.js
            if [ -r "${user_js_file}" ]; then
                grep -v -E '(network\.proxy\.|^// Weizmann proxy settings)' "${user_js_file}"
            fi
            echo '// Weizmann proxy settings'
            printf '%s\n' "${user_mozilla_proxy_prefs[@]}"
        } > "${tmp}"
        install -m 0644 -o "${user_name}" -g "${user_name}" "${tmp}" "${user_js_file}"
        /bin/rm -f "${tmp}"
        message_success "Wrote proxy settings to \"${user_js_file}\""
    done
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
