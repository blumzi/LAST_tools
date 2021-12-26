#!/bin/bash

module_include lib/message
module_include lib/sections

user_ocs="ocs"
user_groups=( sudo dialup )
user_group_list=$( IFS=,; echo "${user_groups[@]}" )

sections_register_section "user" "Manages the \"${user_ocs}\" user"


function user_start() {
    message_section "User \"${user_ocs}\""
    if grep -w "^${user_ocs}" /etc/passwd; then
        message_success "User ${user_ocs} exists"
    else
        message_info "Creating user \"${user_ocs}\" ..."
        useradd -m -G "${user_group_list}" ${user_ocs}
    fi

    local -i ngroups=0
    read -r -a grps <<< "$( groups ${user_ocs} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        if "${g}" in "${user_groups[@]}"; then
            (( ngroups++ ))
        fi
    done
    if (( ngroups != 2 )); then
        message_info "Making \"${user_ocs}\" a member of the groups: ${user_group_list}"
        usermod -G "${user_group_list}" ${user_ocs}
    fi
}

function user_configure() {
    :
}

function user_check() {
    local ret=0

    message_section "User \"${user_ocs}\""
    if grep -w "^${user_ocs}" /etc/passwd; then
        message_success "User \"${user_ocs}\" exists"
    else
        message_failure "User \"${user_ocs}\" does not exit"
        (( ret++ ))
    fi

    local -i ngrps
    read -r -a grps <<< "$( groups ${user_ocs} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        for ug in "${user_groups[@]}"; do
            if [ "${g}" = "${ug}" ]; then
                (( ngrps++ ))
            fi
        done
    done

    if (( ngrps == ${#user_groups[*]} )); then
        message_success "User \"${user_ocs}\" is a member of groups: ${user_group_list}"
    else
        message_failure "User \"${user_ocs}\" is not a member of ALL the groups: ${user_group_list}"
        (( ret++ ))
    fi

    return $(( ret ))
}