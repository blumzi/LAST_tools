#!/bin/bash

module_include lib/message
module_include lib/macmap

#
# Functions related to systemctl services
#
# The <scope> argument can be one of:
#   - all:   do this on all the machines
#   - last0: only on last0
#   - lastx: on all lastXXY machines, but not on last0
#
function service_enforce() {
    local service="${1}"
    local   scope="${2}"
    local     arg="${3}"

    if ! _service_is_relevant_to_this_machine ${scope}; then
        message_success "Service \"${service}\" is not relevant to this machine"
        return
    fi

    local system_file="/lib/systemd/system/${service}.service"
    local our_file="$(module_locate files/root/lib/systemd/system/${service}.service)"

    ln -sf "${our_file}" "${system_file}"
    systemctl daemon-reload
    message_success "Linked \"${our_file}\" to \"${system_file}\"."
    systemctl daemon-reload
    
    local enable=true
    if [ "${arg}" ]; then
        case ${arg} in
		"--enable")
		    enable=true
		    ;;

        "--disable")
            enable=false
            ;;
        esac
    fi

    if ${enable}; then
        if [ "$(systemctl is-enabled ${service})" != enabled ]; then
            if systemctl enable ${service} >/dev/null 2>&1 ; then
                message_success "Enabled the \"${service}\" service"
            else
                message_failure "Failed to enable the \"${service}\" service"
            fi
        else
            message_success "Service \"${service}\" is enabled"
        fi

        if systemctl is-active ${service} >/dev/null 2>&1; then
            message_success "Service \"${service}\" is active"
        else
            if systemctl start ${service} >/dev/null 2>&1; then
                message_success "Started service \"${service}\"."
            else
                message_failure "Failed to start service \"${service}\"."
            fi
        fi
    else
        if [ "$(systemctl is-enabled ${service})" != disabled ]; then
            if systemctl disable ${service} >/dev/null 2>&1 ; then
                message_success "Disabled the \"${service}\" service"
            else
                message_failure "Failed to disable the \"${service}\" service"
            fi
        else
            message_success "Service \"${service}\" is disabled"
        fi

        if ! systemctl is-active ${service} >/dev/null 2>&1; then
            message_success "Service \"${service}\" is not active"
        else
            if systemctl stop ${service} >/dev/null 2>&1; then
                message_success "Stopped service \"${service}\"."
            else
                message_failure "Failed to stop service \"${service}\"."
            fi
        fi
    fi
}

function service_check() {
    local service="${1}"
    local   scope="${2}"
    local -i errors=0

    if ! _service_is_relevant_to_this_machine "${scope}"; then
        message_success "Service \"${service}\" is not relevant to this machine"
        return
    fi

    local system_file="/etc/systemd/system/${service}.service"
    local our_file="$(module_locate files/root/etc/systemd/system/${service}.service)"

    if [ -e ${system_file} ]; then
        message_success "File \"${system_file}\" exists"
    else
        message_failure "File \"${system_file}\" is missing"
        (( errors++ ))
    fi

    if systemctl is-enabled ${service} >/dev/null 2>&1; then
        message_success "Service \"${service}\" is enabled"
    else
        message_warning "Service \"${service}\" is disabled"
        (( errors++ ))
    fi

    if systemctl is-active ${service} >/dev/null 2>&1; then
        message_success "Service \"${service}\" is active"
    else
        message_warning "Service \"${service}\" is not active"
        (( errors++ ))
    fi

    return $(( errors ))
}

function _service_is_relevant_to_this_machine() {
    local scope="${1}"

    case "${scope,,}" in
    all)
        return 0
        ;;

    last0)
        if macmap_this_is_last0; then
            return 0
        else
            return 1
        fi
        ;;

    lastx)
        if macmap_this_is_last0; then
            return 1
        else
            return 0
        fi
        ;;
    esac
}
