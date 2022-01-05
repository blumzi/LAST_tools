#!/bin/bash

module_include lib/macmap
module_include lib/sections

export network_local_hostname network_local_ipaddr network_peer_hostname network_peer_ipaddr
export network_netpart network_netmask network_interface network_gateway network_gateway
export network_broadcast network_prefix

function network_init() {
    network_local_hostname=$( macmap_get_local_hostname )
    network_local_ipaddr=$( macmap_get_local_ipaddr )
    network_peer_hostname=$( macmap_get_peer_hostname )
    network_peer_ipaddr=$( macmap_get_peer_ipaddr )
	local -a info
	read -r -a info <<< "$( ip -o -4 link show | grep ': en' )"
    network_interface=${info[1]}
	network_interface=${network_interface%:}
    network_netmask=255.255.0.0
    network_broadcast=10.23.255.255
    network_netpart=10.23.0.0
    network_gateway=10.23.x.x
    network_prefix=16

    sections_register_section "network" "Configures the LAST network"
}

#
# Creates a proper /etc/network/interfaces for this machine
# We use static addresses.  The actual addresses are deduced from the macmap file.
# The only configured (and active interface) is eth0
#
function network_enforce() {

    if ! LAST_TOOL_QUIET=true network_check_etc_network_interfaces; then
        cat << EOF > /etc/network/interfaces

        #
        # This file was created by ${PROG}, $(date --rfc-email)
        #
        auto ${network_interface}
        iface ${network_interface} inet static 
            address ${network_local_ipaddr}
            network ${network_netpart}
            netmask ${network_netmask}
            broadcast ${network_broadcast}
            gateway ${network_gateway}
EOF
        systemctl restart networking
    fi
}

function network_check_etc_network_interfaces() {
    local config_file="/etc/network/interfaces"

    function callback() {
        local lineno="${1}" line="${2}"

        line="${line%%#*}"
        eval set "${line}"
        if [ ${#} -eq 0 ]; then
            return
        fi

        if ${already_seen_auto_line}; then
            return
        fi

        case "${1}" in
            auto)
                if [ "${2}" = "${network_interface}" ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"auto ${network_interface}\", got \"${line}\"."
                fi
                already_seen_auto_line=true
                ;;

            iface)
                if [ "${1}" = "${network_interface}" ] && [ "${2}" = inet ] && [ "${3}" = static ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"iface ${network_interface} inet static\", got \"${line}\"."
                fi
                ;;

            address)
                if [ "${2}" = "${network_local_ipaddr}" ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"address ${network_local_ipaddr}\", got \"${line}\"."
                fi
                ;;

            network)
                if [ "${2}" = "${network_netpart}" ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"network ${network_netpart}\", got \"${line}\"."
                fi
                ;;

            broadcast)
                if [ "${2}" = "${network_broadcast}" ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"broadcast ${network_broadcast}\", got \"${line}\"."
                fi
                ;;

            gateway)
                if [ "${2}" = "${network_gateway}" ]; then
                    (( OKs++ ))
                else
                    message_failure "${config_file}:${lineno}: Exepcted \"gateway ${network_gateway}\", got \"${line}\"."
                fi
                ;;
        esac
    }

    if [ -r ${config_file} ]; then
		mapfile -t -C callback -c 1 < ${config_file}
		if (( OKs == 6 )); then
			message_success "${config_file} seems OK"
		else
			message_failure "${config_file} has errors"
			(( errors++ ))
		fi
	else
        message_failure "Missing configuration file ${config_file}."
		(( errors++ ))
    fi
}

function network_check() {
    local -a words
    local -i errors
    local -i OKs=0
    local already_seen_auto_line=false

    network_check_etc_network_interfaces

    #  check the Ethernet is up
    read -r -a words <<< "$( ip -o -4 address show dev "${network_interface}")"
    if (( ${#words[*]} != 14 )); then
        message_failure "Interface \"${network_interface}\" is not properly configured"
        (( errors++ ))
    else
        if [ "${words[3]}" = "${network_local_ipaddr}/${network_prefix}" ] && [ "${words[5]}" = "${network_broadcast}" ]; then
            message_success "Interface ${network_interface} is properly configured"
        else
            message_failure "Interface \"${network_interface}\" is not properly configured"
            (( errors++ ))
        fi

        if [[ "$(ip -o -4 link show dev "${network_interface}")" == *,UP\>* ]]; then
            message_success "Interface \"${network_interface}\" is UP"
        else
            message_failure "Interface \"${network_interface}\" is not UP"
            (( errors++ ))
        fi
    fi

    if ! ping -4 -q -c 1 -w 1 last0 >/dev/null 2>&1; then
        message_warning "Cannot ping \"last0\"."
    else
        message_success "Can ping \"last0\"."
    fi

    # check we can ping someone at Weizmann
	local wiz_host
	wiz_host=wisfiler
    if ! ping -4 -q -c 1 -w 1 ${wiz_host} > /dev/null 2>&1; then
        message_warning "Cannot ping \"${wiz_host}\" (no Internet ?!?)."
    else
        message_success "Can ping \"${wiz_host}\", Internet is reachable."
    fi

    return $(( errors ))
}
