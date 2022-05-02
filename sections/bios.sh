#!/bin/bash

module_include lib/message
module_include lib/macmap
module_include lib/sections

sections_register_section "bios" "Manages the machine's BIOS settings"

function bios_enforce() {
    message_warning "We don't know how to enforce the BIOS policy (yet ?!?)"
}

function bios_check() {
    local wakeup_type
    
    if macmap_this_is_last0; then
        message_success "No memory size check on last0"
        return 0
    fi

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

    local nDIMMs
    nDIMMs="$(dmidecode -t memory | grep -c '^[[:space:]]*Size: 32 GB')"    # What if it has different DIMMs?
    if (( nDIMMs == 8 )); then
        message_success "The machine has 8 DIMMs of 32 GB each (total 256 GB) memory"
    else
        message_failure "The machine has only ${nDIMMs} DIMMs of 32 GB each (instead of 8)"
    fi
}

function bios_policy() {
    cat <<- EOF

    - We would like to be able to make the machine boot Linux after a power failure.
       At this point-in-time we don't have a method for enforcing that, (still looking)
    
    - The machines should have 256 GB of installed RAM (8x32 GB)

EOF
}
