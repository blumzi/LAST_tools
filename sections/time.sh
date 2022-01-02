#!/bin/bash

sections_register_section "time" "Manages the time syncronization LAST policy" "network"

declare time_server="ntp.weizmann.ac.il"
declare time_config="/etc/systemd/timesyncd.conf"

function time_enforce() {
    if sed -i -e "s;^[#]?NTP=.*;NTP=${time_server};" "${time_config}"; then
        message_success "Set NTP server to ${time_server} in \"${time_config}\"."
    else
        message_failure "Failed to set NTP server to ${time_server} in \"${time_config}\"."
    fi
}

function time_check() {
    local ret
    
    ret=0

    if grep "^NTP=${time_server}" ${time_config}; then
        message_success "NTP server is configured as \"ntp.weizmann.ac.il\" in \"${time_config}\"."
    else
        message_failure "NTP server is not well configured in \"${time_config}\"."
        (( ret++ ))
    fi

    return $(( ret ))
}