#!/bin/bash

module_include lib/message
module_include lib/sections

export user_last="ocs"
export -a user_groups=( sudo dialup )
export user_group_list
user_group_list="$( IFS=,; echo ${user_groups[*]} )"

sections_register_section "user" "Manages the \"${user_last}\" user"

function user_enforce() {
    message_section "User \"${user_last}\""
    if grep -w "^${user_last}:" /etc/passwd; then
        message_success "User ${user_last} exists"
    else
        message_info "Creating user \"${user_last}\" ..."
        useradd -m -G "${user_group_list}" ${user_last}
    fi

    local -i ngroups=0
    read -r -a grps <<< "$( groups ${user_last} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        if "${g}" in "${user_groups[@]}"; then
            (( ngroups++ ))
        fi
    done
    if (( ngroups != 2 )); then
        message_info "Making \"${user_last}\" a member of the groups: ${user_group_list}"
        usermod -G "${user_group_list}" ${user_last}
    fi

	local bashrc
	bashrc=/home/${user_last}/.bashrc
	if [ -r ${bashrc} ] ;then
		local tmp
		tmp=$(mktemp)
		if [ "$( grep -E -c '(export http_proxy=http://bcproxy.weizmann.ac.il:8080|export https_proxy=http://bcproxy.weizmann.ac.il:8080|unset TMOUT)' ${bashrc} )" != 3 ]; then
			{
				cat /etc/skel/.bashrc
				cat << EOF
				
				export http_proxy=http://bcproxy.weizmann.ac.il:8080
				export https_proxy=http://bcproxy.weizmann.ac.il:8080
				unset TMOUT
EOF
			} > "${tmp}"
			install -D --mode 644 --owner "${user_last}" --group "${user_last}" "${tmp}" ${bashrc}
			rm -f "${tmp}"

			message_success "Regenerated ${bashrc}"
		else
			message_failure "Missing ${bashrc}"
		fi
    else
        message_success "~${user_last}/.bashrc complies"
    fi
}

function user_check() {
    local ret=0

    message_section "User \"${user_last}\""
    if grep -w "^${user_last}:" /etc/passwd; then
        message_success "User \"${user_last}\" exists"
    else
        message_failure "User \"${user_last}\" does not exit"
        (( ret++ ))
    fi

    local -i ngrps
    read -r -a grps <<< "$( groups ${user_last} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        for ug in "${user_groups[@]}"; do
            if [ "${g}" = "${ug}" ]; then
                (( ngrps++ ))
            fi
        done
    done

    if (( ngrps == ${#user_groups[*]} )); then
        message_success "User \"${user_last}\" is a member of groups: ${user_group_list}"
    else
        message_failure "User \"${user_last}\" is not a member of ALL the groups: ${user_group_list}"
        (( ret++ ))
    fi

    local rcfile
    rcfile=/home/${user_last}/.bashrc
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
