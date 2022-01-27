#!/bin/bash

module_include lib/macmap
module_include lib/sections

export network_local_hostname network_local_ipaddr network_peer_hostname network_peer_ipaddr
export network_netpart network_netmask network_interface network_gateway network_gateway
export network_broadcast network_prefix

function network_set_defaults() {
    network_local_hostname=$( macmap_get_local_hostname )
    network_local_ipaddr=$( macmap_get_local_ipaddr )
    network_peer_hostname=$( macmap_get_peer_hostname )
    network_peer_ipaddr=$( macmap_get_peer_ipaddr )
	local -a info
	read -r -a info <<< "$( ip -o -4 link show | grep ': en' )"
    network_interface=${info[1]}
	network_interface=${network_interface%:}
    network_netmask=255.255.255.0
    network_broadcast=10.23.1.255
    network_netpart=10.23.1.0
    network_gateway=10.23.1.254
    network_prefix=24
}

function network_init() {
    sections_register_section "network" "Configures the LAST network"
}

#
# Creates a netplan configuration file for this machine
# We use static addresses.  The actual addresses are deduced from the macmap file.
# The only configured (and active interface) should be enp67s0
#
function network_enforce() {

    network_set_defaults

    cat <<- EOF > /etc/netplan/99_last_network.yaml
    network:
        version: 2
        renderer: networkd
        ethernets:
          ${network_interface}:
            dhcp4: false
            addresses:
             - ${network_local_ipaddr}/${network_prefix}
            gateway4: ${network_gateway}
            nameservers:
              addresses: [132.77.4.1, 132.77.22.1]
              search: [wisdom.weizmann.ac.il, wismain.weizmann.ac.il, weizmann.ac.il]
EOF

    netplan apply
}

function network_check() {
    local -a words
    local -i errors

    network_set_defaults

    #  check the Ethernet is up
    read -r -a words <<< "$( ip -o -4 address show dev "${network_interface}")"
    if (( ${#words[*]} != 13 )); then
        message_failure "Interface \"${network_interface}\" is not properly configured"
        (( errors++ ))
    else
        if [ "${words[3]}" = "${network_local_ipaddr}/${network_prefix}" ] && [ "${words[5]}" = "${network_broadcast}" ]; then
            message_success "Interface ${network_interface} is properly configured"
        else
            message_failure "Interface \"${network_interface}\" is not properly configured"
            (( errors++ ))
        fi

        if [[ "$(ip -o -4 link show dev "${network_interface}")" == *,UP,LOWER_UP* ]]; then
            message_success "Interface \"${network_interface}\" is UP"
        else
            message_failure "Interface \"${network_interface}\" is not UP"
            (( errors++ ))
        fi
    fi

    # last0 is on the local network, should be pingable
    if ! ping -4 -q -c 1 -w 1 last0 >/dev/null 2>&1; then
        message_warning "Cannot ping \"last0\"."
    else
        message_success "Can ping \"last0\"."
    fi

    # Machines on weizmann.ac.il should be reachable via the HTTP proxy
    if wget -O - http://euler1.weizmann.ac.il/catsHTM 2>/dev/null | grep -qs 'large catalog format'; then
        message_success "Succeeded reaching the weizmann.ac.il network (got the http://euler1.weizmann.ac.il/catsHTM page)"
    else
        message_warning "Failed reaching the weizmann.ac.il network (could not wget the http://euler1.weizmann.ac.il/catsHTM page)"
        (( errors++ ))
    fi

    return $(( errors ))
}

function network_policy() {

    network_set_defaults

    cat <<- EOF

    There is a single Ethernet adapter in each LAST machine.

    At this point-in-time the LAST project uses static allocation of the IP addresses.  In the 
     future we may opt for dynamic alocations (via DHCP) from the main IP switch.

    - The network is maintained by netplan(5).
    - The file "/etc/netplan/99_last_network.yaml" is created and contains the LAST network (static) configuration.
    
    - The network must be UP on the Ethernet adapter.
    - The last0 machine must be reachable (ping)
    - A machine at the Weizmann Institute must be reachable (wget via HTTP proxy)

EOF
}
