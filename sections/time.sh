#!/bin/bash

sections_register_section "time" "Manages the time syncronization LAST policy" "network"

#
# Theory of operation:
#  - At some point-in-time we'll have a GPS-based NTP server (from SiTech) on our local network.
#     It should be our primary server (hostname: sitechntp).
#  - In the meanwhile our primary server should be ntp.weizmann.ac.il.
#     It will become secondary once we get the SiTech NTP server.
#

export time_config="/etc/systemd/timesyncd.conf"
export -a time_servers=( sitechntp ntp.weizmann.ac.il )
export time_servers_list
time_servers_list="$(IFS=,; echo "${time_servers[*]}")"

export time_service="systemd-timesyncd"

function time_enforce() {
    if sed -i -e "s;^[#]*NTP=.*;NTP=${time_servers[*]};" "${time_config}"; then
        message_success "Set NTP server(s) to ${time_servers_list} in \"${time_config}\"."
    else
        message_failure "Failed to set NTP server(s) (${time_servers_list}) in \"${time_config}\"."
        return
    fi

    systemctl restart ${time_service}
}

function time_check() {
    local ret
    
    ret=0

    if grep "^NTP=${time_servers[*]}" ${time_config} >/dev/null; then
        message_success "NTP server(s) (${time_servers_list}) are properly configured in \"${time_config}\"."
    else
        message_failure "NTP server(s) (${time_servers_list}) are not well configured in \"${time_config}\"."
        (( ret++ ))
    fi

    if sytemctl status ${time_service} >/dev/null; then
        message_success "Time sync service is running"
    else
        message_failure "Time sync service is NOT running"
    fi

    return $(( ret ))
}

function time_policy() {
    cat <<- EOF

    LAST uses an on-site NTP server (by SiTech Inc.) as primary server and the Weizmann Institute's
     ntp.weizmann.ac.il as the secondary.

    - The config file /etc/systemd/timesync.conf should reflect this in it's NTP= line
    - The systemd-timesyncd service should be running
    
EOF
}