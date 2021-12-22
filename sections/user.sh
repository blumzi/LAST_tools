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

    local is_sudo_member=false
    readarray -d ' ' grps < <( groups ${user_ocs} 2>&- | sed -e 's;^.*:.;;' )
    if [ ${#grps[@]} -gt 0 ]; then
        for g in "${grps[@]}"; do
            if [ "${g}" == sudo ]; then
                is_sudo_member=true
                break
            fi
        done
        if ! ${is_sudo_member}; then
            message_info "Making \"${user_ocs}\" a member of the \"sudo\" group"
            usermod -G sudo ${user_ocs}
        fi
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
    
    if groups ${user_ocs} 2>&- | grep -w sudo >&-; then
        message_success "User \"${user_ocs}\" is a member of the sudo group"
    else
        message_failure "User \"${user_ocs}\" is NOT a member of the sudo group"
    fi
}