#!/bin/bash

module_include lib/message
module_include lib/sections

user_ocs="ocs"

sections_register_section "user" "Manages the \"${user_ocs}\" user"


function user_run() {
    message_section "User \"${user_ocs}\""
    if grep -w "^${user_ocs}" /etc/passwd; then
        message_success "User ${user_ocs} exists"
    else
        message_info "Creating user \"${user_ocs}\" ..."
        useradd -m -G sudo ${user_ocs}
    fi

    local ngroups=0
    read -r -a grps <<< "$( groups ${user_ocs} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        if [ "${g}" == sudo ] || [ "${g}" = dialup ]; then
            (( ngroups++ ))
        fi
    done
    if [ "${ngroups}" -ne 2 ]; then
        message_info "Making \"${user_ocs}\" a member of the \"sudo\" and \"dialup\" groups"
        usermod -G sudo,dialup ${user_ocs}
    fi
}

function user_configure() {
    :
}

function user_check() {
    message_section "User \"${user_ocs}\""
    if grep -w "^${user_ocs}" /etc/passwd; then
        message_success "User \"${user_ocs}\" exists"
    else
        message_failure "User \"${user_ocs}\" does not exit"
    fi

    local is_sudo=false is_dialup=false
    read -r -a grps <<< "$( groups ${user_ocs} 2>&- | sed -e 's;^.*:.;;' )"
    for g in "${grps[@]}"; do
        [ "${g}" = sudo ]   && is_sudo=true
        [ "${g}" = dialup ] && is_dialup=true
    done

    ${is_sudo} &&
        message_success "User \"${user_ocs}\" is a member of the \"sudo\" group" ||
        message_failure "User \"${user_ocs}\" is not a member of the \"sudo\" group"

    ${is_dialup} &&
        message_success "User \"${user_ocs}\" is a member of the \"dialup\" group" ||
        message_failure "User \"${user_ocs}\" is not a member of the \"dialup\" group"
}