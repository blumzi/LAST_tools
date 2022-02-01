#!/bin/bash

module_include lib/message
module_include lib/sections

export ssh_config_file=/etc/ssh/ssh_config

sections_register_section "ssh" "Configures ssh client"

function ssh_enforce() {
    
    if [ "$(grep -scE '^[[:space:]]*ServerAlive' "${ssh_config_file}")" != 2 ]; then
        local tmp
        tmp=$(mktemp)

        {
            grep -Ev '^[[:space:]]*ServerAlive(CountMax|Interval)' "${ssh_config_file}"
            echo '    ServerAliveCountMax 4'
            echo '    ServerAliveInterval 15'
        } > "${tmp}"
        mv "${tmp}" ${ssh_config_file}
        chmod 644 ${ssh_config_file}
		message_success "Added ServerAlive settings to config file ${ssh_config_file}"
	fi
}

function ssh_check() {
    if [ "$(grep -scE '^[[:space:]]*ServerAlive' "${ssh_config_file}")" = 2 ]; then
        message_success "Ssh config file (${ssh_config_file}) has the ServerAlive settings"
    else
        message_failure "Ssh config file (${ssh_config_file}) does not have the ServerAlive settings"
    fi
}

function ssh_policy() {
    cat <<- EOF

    - The ssh configuration file (${ssh_config_file}) should contain settings for:
      - ServerAliveCountMax  4
      - ServerAliveInterval 15

      This tells the ssh client to try every 15 seconds for at most 4 times (total of 1 minute)
       to get proof of life from the server, before closing the connection.

EOF
}
