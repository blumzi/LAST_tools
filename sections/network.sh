#!/bin/bash

module_include lib/macmap
module_include lib/sections
module_include lib/ipv4
module_include lib/wget
module_include lib/service

export network_local_hostname network_local_ipaddr network_peer_hostname network_peer_ipaddr
export network_netpart network_netmask network_interface network_gateway network_gateway
export network_broadcast network_prefix

function network_set_defaults() {
    network_local_hostname=$( macmap_get_local_hostname )
    network_local_ipaddr=$( macmap_get_local_ipaddr )
    if ! macmap_this_is_last0; then
        network_peer_hostname=$( macmap_get_peer_hostname )
        network_peer_ipaddr=$( macmap_get_peer_ipaddr )
    fi
	local -a info
	read -r -a info <<< "$( ip -o -4 link show | grep ': en' )"
    network_interface=${info[1]%:}

    network_prefix=24
    network_broadcast=$(ipv4_broadcast "${network_local_ipaddr}" ${network_prefix})
      network_netmask=$(ipv4_netpart   255.255.255.255           ${network_prefix})
      network_netpart=$(ipv4_netpart   "${network_local_ipaddr}" ${network_prefix})
      network_gateway=$(ipv4_gateway   "${network_local_ipaddr}" ${network_prefix})
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
    local plan="/etc/netplan/99_last_network.yaml"
    local tmp
    
    tmp=$(mktemp)

    network_set_defaults

    cat <<- EOF > "${tmp}"
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
	if [ -e "${plan}" ]; then
		if cmp --silent "${tmp}" "${plan}"; then
			message_success "Netplan \"${plan}\" is already valid."
		else
			cp "${tmp}" "${plan}"
			message_success "Overwritten plan \"${plan}\""
		fi
	else
		cp "${tmp}" "${plan}"
		message_success "Created netplan \"${plan}\""
	fi
	/bin/rm "${tmp}"

    netplan apply
    message_success "Applied netplan \"${plan}\""

    network_enforce_ethernet_advertising
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
    if ! timeout 2 ping -4 -q -c 1 -W 1 last0 >/dev/null 2>&1; then
        message_warning "last-network: Cannot ping \"last0\"."
        (( errors++ ))
    else
        message_success "last-network: Can ping \"last0\"."
    fi

    # Machines on weizmann.ac.il should be reachable via the HTTP proxy
    if curl -x ${http_proxy} -I google.com >/dev/null 2>&1; then
	    message_success "WIS-network:  Succeeded using the Weizmann HTTP proxy (${http_proxy}) to reach google.com"
    else
	    message_failure "WIS-network:  Failed using the Weizmann HTTP proxy (${http_proxy}) to reach google.com"
        (( errors++ ))
    fi

    # Machines OUTSIDE weizmann.ac.il should be reachable via the HTTP proxy
    if wget ${WGET_OPTIONS} --timeout=2 --output-document=- --tries=2 http://google.com 2>/dev/null | grep -qs '<!doctype html>'; then
        message_success "Internet:     Succeeded reaching the Internet (got the http://google.com page)"
    else
        message_warning "Internet:     Failed reaching the Internet (could not wget the http://google.com page)"
        (( errors++ ))
    fi

    local target this_host
    this_host="$(hostname -s)"
    for target in $(last-hosts --deployed); do
        if [ "${target}" = "${this_host}" ]; then
            continue
        fi
        if timeout 2 ping -4 -q -c 1 -W 1 "${target}" >/dev/null 2>&1; then
            message_success "${target} is reachable (ping)"
        else
            message_failure "${target} is NOT reachable (ping)"
            (( errors++ ))
        fi
    done

    local pswitches=( $(last-hosts --deployed | sed -e 's;\<last0\>.;;' -e 's;last;pswitch;g' ) )
    for target in ${pswitches[*]}; do
        if http_proxy='' wget ${WGET_OPTIONS} -O - "http://admin:admin@${target}/st0.xml" >/dev/null 2>&1; then
            message_success "${target} is reachable (wget st0.xml)"
        else
            message_failure "${target} is NOT reachable (wget st0.xml)"
            (( errors++ ))
        fi
    done

    network_check_ethernet_advertising

    return $(( errors ))
}

function network_enforce_ethernet_advertising() {
    local config="/lib/systemd/network/99-default.link"
    local expected="1000baset-full"

    local tmp=$(mktemp)
    {
        grep -v 'Advertise=' ${config}
        echo Advertise=${expected}
    } > ${tmp}
    mv ${tmp} ${config}
    systemctl reload systemd-udevd
    message_success "Enforced udev ethernet advertisement ${expected} (${config})"
}

function network_check_ethernet_advertising() {
    local config="/lib/systemd/network/99-default.link"
    local expected="1000baset-full"

    IFS='=' read _ value <<< $(grep Advertise= ${config})
    if [ "${value}" = ${expected} ]; then
        message_success "Udev is set to advertise ${expected} (${config})"
    else
        message_failure "Udev is NOT set to advertise ${expected} (${config})"
        return 1
    fi
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
