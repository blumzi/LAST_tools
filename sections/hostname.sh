#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "hostname" "Manages stuff related to the machine's host name"

function hostname_enforce() {
    :
}

function hostname_configure() {
    message_section "Hostname"

    if ! hostname_is_valid "${LAST_HOSTNAME}"; then
        message_failure "Invalid hostname \"${LAST_HOSTNAME}\""
        return
    fi
    hostnamectl --static "${LAST_HOSTNAME}"

    # TODO: /etc/hosts alias
}

function hostname_make_name() {
    local mount=$(( ${1} )) # transform to integer
    local side=${2}

    if [ ${mount} -lt 1 ] || [ ${mount} -gt 24 ]; then
        message_fatal "${FUNCNAME[0]}: Bad mount number \"${mount}\" (should be 1..24)"
    fi
    if [ "${side}" != 'e' ] && [ "${side}" != 'w' ]; then
        message_fatal "${FUNCNAME[0]}: Bad side \"${side}\" (should be 'e' or 'w')"
    fi
    
    printf "%02d%s" ${mount} "${side}"
}

function hostname_check() {
    message_section "Hostname"

    if ! hostname_is_valid "${LAST_HOSTNAME}"; then
        message_failure "Invalid hostname \"${LAST_HOSTNAME}\""
        return
    fi

    # Check if the current host's name is as expected
    local current_hostname
    current_hostname="$(hostname)"

    if [ "${LAST_HOSTNAME}" = "${current_hostname}" ]; then
        message_success "The hostname is \"${current_hostname}\""
    else
        message_failure "The hostname is \"${current_hostname}\" instead of \"${LAST_HOSTNAME}\""
    fi

    if hostname_is_valid "${current_hostname}"; then
        message_success "The hostname \"${current_hostname}\" is a valid LAST hostname"
    else
        message_failure "The hostname \"${current_hostname}\" is not a valid LAST hostname"
    fi

    local -a hostnames
    hostnames=( last0 )
    for ((mount = 1; mount <= 12; mount++)); do
        for side in 'e' 'w'; do
            hostnames+=( "$(hostname_make_name "${mount}" "${side}")" )
        done
    done

    local -a missing
    for hostname in "${hostnames[@]}"; do
        grep -wq "${hostname}" /etc/hosts >/dev/null || missing+=( "${hostname}" )  
    done
    if [ ${#missing[*]} -gt 0 ]; then        
        message_failure "Missing entries for hostname(s) \"${missing[*]}\" in /etc/hosts"
    else
        message_success "All LAST hosts have entries in /etc/hosts."
    fi 
}

#
# Checks conformity to the LAST host naming convention
#  Valid names are:
#    last0: master
#    lastXXY: where XX (mount id) is 01..12 and Y (side id) is 'e' or 'w'
#
function hostname_is_valid() {
    local name="${1}"

    if [ ! "${name}" ] && [ "${LAST_HOSTNAME}" ]; then
        name=${LAST_HOSTNAME}
    fi

    [[ ${name} != last* ]] || return 1

    if [ "${name}" != last0 ] && [[ "${name}" != last[01][0-9][ew] ]]; then
        return 1
    fi

    local mount_id
    mount_id=${name#last}
    mount_id=${mount_id%[ew]}
    mount_id=$(( mount_id ))
    (( mount_id < 1 || mount_id > 24 )) || return 1

    return 0
}