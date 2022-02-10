#!/bin/bash

module_include lib/message
module_include lib/sections

export user_last="ocs"
eval export user_home=~${user_last}
# shellcheck disable=SC2154
export user_matlab_dir="${user_home}/matlab"
export -a user_expected_groups=( sudo dialout )
export user_expected_groups_list
user_expected_groups_list="$(IFS=,; echo "${user_expected_groups[*]}")"

sections_register_section "user" "Manages the \"${user_last}\" user"

function user_enforce() {
    if grep "^${user_last}:" /etc/passwd >/dev/null; then
        message_success "User ${user_last} exists"

        local expected found
        local -a missing
        read -r -a groups <<< "$( groups ${user_last} 2>/dev/null | sed -e 's;^.*:.;;' )"
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
            message_info "Making \"${user_last}\" a member of the groups: ${user_expected_groups_list}"
            usermod -G "${user_expected_groups_list}" ${user_last}
		else
			message_success "User ${user_last} is a member of groups: ${user_expected_groups_list}"
        fi
    else
        message_info "Creating user \"${user_last}\" ..."
        useradd -m -G "${user_expected_groups_list}" ${user_last}
    fi

	if [ "${user_home}" = "/home/${user_last}" ]; then
		message_success "The user's home is \"/home/${user_last}\"."
	else
		local old_home
		eval old_home=~${user_last}
		sed -i "s;${old_home}:;/home/${user_last}:;" /etc/passwd
		mv "${old_home}" "/home/${user_last}"
        rmdir "$(dirname ${old_home})"
		message_success "Changed the user's home from \"${user_home}\" to \"/home/${user_last}\"."
	fi
	eval export user_home=~"${user_last}"

    if [ "$(stat --format '%U.%G' "${user_home}")" != "${user_last}.${user_last}" ]; then
        chown ${user_last}.${user_last} "${user_home}"
        message_success "Changed ownership of ${user_home} to ${user_last}.${user_last}"
    fi

	local bash_profile
	bash_profile="${user_home}/.bash_profile"
	if [ ! -r "${bash_profile}" ] || [ "$( grep -E -c '(export http_proxy=http://bcproxy.weizmann.ac.il:8080|export https_proxy=http://bcproxy.weizmann.ac.il:8080|unset TMOUT)' ${bash_profile} )" != 3 ]; then
		local tmp
		tmp=$(mktemp)
		{
			cat <<- EOF
			
			export http_proxy=http://bcproxy.weizmann.ac.il:8080
			export https_proxy=http://bcproxy.weizmann.ac.il:8080
			unset TMOUT
EOF
		} > "${tmp}"
		install -D --mode 644 --owner "${user_last}" --group "${user_last}" "${tmp}" "${bash_profile}"
		rm -f "${tmp}"

		message_success "Regenerated ${bash_profile}"
    else
        message_success "${bash_profile} complies"
    fi
    # shellcheck disable=SC1090
    source "${bash_profile}"

    eval export user_matlab_dir="${user_home}/matlab"
    if [ -d "${user_matlab_dir}" ]; then
        message_success "The directory \"${user_matlab_dir}\" exists"
    else
        mkdir -p "${user_matlab_dir}"
        chown ${user_last}.${user_last} "${user_matlab_dir}"
        message_success "Created the \"${user_matlab_dir}\" directory."
    fi

    user_enforce_mozilla_proxy
}

function user_check() {
    local ret=0
    local -a groups

    if grep "^${user_last}:" /etc/passwd >/dev/null; then
        message_success "User \"${user_last}\" exists"
    else
        message_failure "User \"${user_last}\" does not exit"
        (( ret++ ))
    fi

    local found
    local -a missing
    read -r -a groups <<< "$( groups ${user_last} 2>/dev/null | sed -e 's;^.*:.;;' )"
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
        message_success "User \"${user_last}\" is a member of groups: ${user_expected_groups_list}"
    else
        message_failure "User \"${user_last}\" is not a member of the group(s): $(IFS=,; echo "${missing[*]}")"
        (( ret++ ))
    fi

	if [ "${user_home}" = /home/${user_last} ]; then
		message_success "The user's home is \"/home/${user_last}\"."
	else
		message_failure "The user's home is NOT \"/home/${user_last}\" (it is \"${user_home}\")."
	fi

    local rcfile
    rcfile="${user_home}/.bash_profile"
	if [ -r "${rcfile}" ]; then
		if [ "$( grep -E -c '(export http_proxy=http://bcproxy.weizmann.ac.il:8080|export https_proxy=http://bcproxy.weizmann.ac.il:8080|unset TMOUT)' "${rcfile}" )" = 3 ]; then
			message_success "${rcfile} complies"
		else
			message_failure "${rcfile} does not have all the required code"
			(( ret++ ))
		fi
	else
		message_failure "Missing \"${rcfile}\""
		(( ret++ ))
	fi

    if [ -d "${user_matlab_dir}" ]; then
		message_success "The directory \"${user_matlab_dir}\" exists"
    else
		message_failure "The directory \"${user_matlab_dir}\" is missing"
    fi

    user_check_mozilla_proxy; (( ret += ${?} ))

    return $(( ret ))
}

function user_check_mozilla_proxy() {
    local errors=0
    local user_js_file
    eval user_js_file=~"${user_last}/.mozilla/firefox/*.default/user.js"

    if [ ! -r "${user_js_file}" ]; then
        message_failure "The Mozilla user.js file is missing"
        return 1
    else
        message_success "The Mozilla user.js file exists."
    fi
    
    if (( $(grep -c -E 'user_pref\("network\.proxy\.(type|HTTP|HTTPS)"' "${user_js_file}") == 3 )); then
        messgage_success "The Mozilla user.js file has entries for network.proxy.(type|HTTP|HTTPS)"
    else
        message_failure "The Mozilla user.js file does not have entries for network.proxy.(type|HTTP|HTTPS)"
        (( errors++ ))
    fi

    return $(( errors ))
}

function user_enforce_mozilla_proxy() {
    local user_js_file
    eval user_js_file=~"${user_last}/.mozilla/firefox/*.default/user.js"
    cat <<- EOF > "${user_js_file}"
    // Weizmann proxy settings
    user_pref("network.proxy.type", "1");
    user_pref("network.proxy.HTTP", "http://bcproxy.weizmann.ac.il:8080");
    user_pref("network.proxy.HTTPS", "http://bcproxy.weizmann.ac.il:8080");
EOF
}

function user_policy() {
    cat <<- EOF

    All the LAST processes and resources are owned by the user "${user_last}"

    - The user must exist and be a member of the sudo and dialout groups
    - The user's home directory should be /home/${user_last}
    - The directory ~${user_last}/matlab must exist
    - The file ~${user_last}/.bash_profile should contain code for:
     - using the Weizmann Institute's HTTP(s) proxies
     - unsetting the bash TMOUT variable, so that sessions will not time out
    
EOF
}
