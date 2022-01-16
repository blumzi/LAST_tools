#!/bin/bash

module_include lib/message
module_include lib/sections

export user_last="ocs"
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

	local bash_profile
	bash_profile=/home/${user_last}/.bash_profile
	if [ ! -r "${bash_profile}" ] || [ "$( grep -E -c '(export http_proxy=http://bcproxy.weizmann.ac.il:8080|export https_proxy=http://bcproxy.weizmann.ac.il:8080|unset TMOUT)' ${bash_profile} )" != 3 ]; then
		local tmp
		tmp=$(mktemp)
		{
			cat /etc/skel/.bash_profile
			cat <<- EOF
			
			export http_proxy=http://bcproxy.weizmann.ac.il:8080
			export https_proxy=http://bcproxy.weizmann.ac.il:8080
			unset TMOUT
EOF
		} > "${tmp}"
		install -D --mode 644 --owner "${user_last}" --group "${user_last}" "${tmp}" ${bash_profile}
		rm -f "${tmp}"

		message_success "Regenerated ${bash_profile}"
    else
        message_success "${bash_profile} complies"
    fi
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

    local rcfile
    rcfile=/home/${user_last}/.bash_profile
	if [ -r ${rcfile} ]; then
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

    return $(( ret ))
}

function user_policy() {
    cat <<- EOF

    All the LAST processes and resources are owned by the user "ocs"

    - The user must exist and be a member of the sudo and dialout groups
    - The file ~ocs/.bash_profile should contain code for:
     - using the Weizmann Institute's HTTP(s) proxies
     - unsetting the bash TMOUT variable, so that sessions will not time out
    
EOF
}