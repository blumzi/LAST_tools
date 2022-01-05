#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "bios" "Manages the machine's BIOS settings"

function bios_enforce() {
    :
}

function bios_check() {
    local wakeup_type
    
    if [ "$(id -un)" != root ]; then
        message_failure "Must be root to read BIOS info"
        return
    fi

    wakeup_type="$(dmidecode -H 1 2>/dev/null | grep 'Wake-up Type:' | sed -e 's;^.*:.;;')"
    if [ ! "${wakeup_type}" ]; then
        message_failure "Could not get the wakeup type"
        return
    fi

    if [ "${wakeup_type}" = "Power Switch" ]; then
        message_warning "Wake-up is: $(ansi_bright_red "Power Switch")"
    fi
}