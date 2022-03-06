#!/bin/bash

sections_register_section "time" "Manages the LAST project time syncronization" "network"

export time_config_file="/etc/systemd/timesyncd.conf"
export -a time_servers=( sitechntp ntp.weizmann.ac.il )
export time_servers_list
time_servers_list="$(IFS=,; echo "${time_servers[*]}")"

export time_service="systemd-timesyncd"

function time_enforce() {
    if sed -i -e "s;^[#]*NTP=.*;NTP=${time_servers[*]};" "${time_config_file}"; then
        message_success "Set NTP server(s) to ${time_servers_list} in \"${time_config_file}\"."
    else
        message_failure "Failed to set NTP server(s) (${time_servers_list}) in \"${time_config_file}\"."
        return
    fi

    systemctl restart ${time_service}
}

function time_check() {
    local ret
    
    ret=0

    if grep "^NTP=${time_servers[*]}" ${time_config_file} >/dev/null; then
        message_success "NTP server(s) (${time_servers_list}) are properly configured in \"${time_config_file}\"."
    else
        message_failure "NTP server(s) (${time_servers_list}) are not well configured in \"${time_config_file}\"."
        (( ret++ ))
    fi

    if systemctl status ${time_service} >/dev/null; then
        message_success "The ${time_service} service is running"
    else
        message_failure "The ${time_service} service is NOT running"
    fi

	if [ "$(timedatectl show --value --property NTPSynchronized)" = yes ]; then
		message_success "NTP is synchronized"
	else
		message_warning "NTP is not synchronized"
	fi

    local tz
    tz="$(timedatectl show --value -p Timezone)"
    if [ "${tz}" = UTC ]; then
        message_success "The timezone is UTC"
    else
        message_failure "The timezone is \"${tz}\" instead of UTC"
        (( ret++ ))
    fi

    return $(( ret ))
}

function time_policy() {
    cat <<- EOF

    Time synchronization:

        LAST uses an on-site NTP server (by SiTech Inc.) as primary server and the Weizmann Institute's
        ntp.weizmann.ac.il as the secondary.

        - The config file ${time_config_file} should reflect this in it's NTP= line
        - The ${time_service} service should be running

    Time zone:
        - UTC
    
EOF
}
