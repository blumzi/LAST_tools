#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "hostname" "Manages stuff related to the machine's host name"

function hostname_configure() {
    message_section "Hostname"

    if ! hostname_is_valid "${LAST_HOSTNAME}"; then
        message_failure "Invalid hostname \"${LAST_HOSTNAME}\""
        return
    fi
    hostnamectl --static "${LAST_HOSTNAME}"

    # TODO: /etc/hosts alias
}

function hostname_check() {
    message_section "Hostname"

    if ! hostname_is_valid "${LAST_HOSTNAME}"; then
        message_failure "Invalid hostname \"${LAST_HOSTNAME}\""
        return
    fi

    local current_hostname
    current_hostname="$(hostname)"

    if [ "${LAST_HOSTNAME}" = "${current_hostname}" ]; then
        message_success "The hostname is \"${current_hostname}\""
    else
        message_failure "The hostname is \"${current_hostname}\" instead of \"${LAST_HOSTNAME}\""
    fi


    # TODO: /etc/hosts alias
}

function hostname_is_valid() {
    local name="${1}"

    if [ ! "${name}" ] && [ "${LAST_HOSTNAME}" ]; then
        name=${LAST_HOSTNAME}
    fi

    if [[ "${name}" != last0 ]] && [[ "${name}" != last[01][0-9][ew] ]]; then
        return 1
    fi

    local mount_id
    mount_id=${name#last}
    mount_id=${mount_id%[ew]}
    mount_id=$(( mount_id ))
    if (( mount_id < 1 || mount_id > 24 )); then
        return 1
    fi

    return 0
}