#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/util

sections_register_section "ubuntu-services" "Stop and mask (disable) ubuntu services not needed by LAST" "ubuntu-packages"

ubuntu_services_file="$(module_locate files/ubuntu-services)"

ubuntu_services=( $(util_uncomment "${ubuntu_services_file}" | sort --unique ) )

function ubuntu_services_enforce() {
    local service

    for service in ${ubuntu_services[*]}; do
        systemctl stop ${service} >/dev/null 2>&1
        systemctl mask ${service} >/dev/null 2>&1
        message_success "Service \"${service}\" was stopped and masked."
    done
}

function ubuntu_services_check() {
    local service msg active enabled isActive isEnabled
    local ret=0

    for service in ${ubuntu_services[*]}; do
        active=$(systemctl is-active ${service} 2>/dev/null);   isActive=$?
        enabled=$(systemctl is-enabled ${service} 2>/dev/null); isEnabled=$?

        if [ ! ${isActive} = 0 ] && [ ! ${isEnabled} = 0 ]; then
            message_success "Service \"${service}\" is stopped and masked"
        else
            message_failure "Service \"${service}\" is ${active} and ${enabled}"
            if (( ret == 0 )); then
                ret=1
            fi
        fi
    done
    return ${ret}
}

function ubuntu_services_policy() {
    cat <<- EOF

    The LAST project is based on an 'Ubuntu 20.04.03 workstation LTS' installation.
    We don't need some of the services that get enabled by the distribution and use
     the "${ubuntu_services_file}" file to stop and disable them

    The list of currently disabled services is:

EOF
    local service
    for service in "${ubuntu_services[@]}"; do
        echo "          ${service}"
    done
    echo ''
}
