#!/bin/bash

module_include macmap
module_include sections

declare network_local_hostname network_local_ipaddr network_peer_hostname network_peer_ipaddr
declare network_netpart network_netmask network_interface network_gateway network_gateway
declare network_broadcast network_prefix

function network_init() {
    network_local_hostname=$( macmap_get_local_hostname )
    network_local_ipaddr=$( macmap_get_local_ipaddr )
    network_peer_hostname=$( macmap_get_peer_hostname )
    network_peer_ipaddr=$( macmap_get_peer_ipaddr )
    network_interface=eth0
    network_netmask=255.255.0.0
    network_broadcast=10.23.255.255
    network_netpart=10.23.0.0
    network_gateway=10.23.x.x
    network_prefix=16

    sections_register_section "network" "Configures the LAST network"
}

function network_start() {
    systemctl restart networking
}

#
# Creates a proper /etc/network/interfaces for this machine
# We use static addresses.  The actual addresses are deduced from the macmap file.
# The only configured (and active interface) is eth0
#
function network_configure() {

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
}

function network_check() {
    local -a words
    local -i errors
    local config_file="/etc/network/interfaces"
    local -i OKs=0
    local already_seen_auto_line=false

    # check /etc/network/interfaces
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
                if [ "${2}" = ${network_interface} ]; then
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

    if [ ! -r ${config_file} ]; then
        message_failure "Missing configuration file ${config_file}."
    fi

    mapfile -t -C callback -c 1 < ${config_file}
    if (( OKs == 6 )); then
        message_success "${config_file} seems OK"
    else
        message_failure "${config_file} has errors"
        (( errors++ ))
    fi

    #  check eth0 is up
    read -r -a words <<< "$( ip -o -4 a dev ${network_interface})"
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

        if [[ "$(ip -o -4 link show dev ${network_interface})" == *,UP\>* ]]; then
            message_success "Interface \"${network_interface}\" is UP"
        else
            message_failure "Interface \"${network_interface}\" is not UP"
            (( errors++ ))
        fi
    fi

    if ! ping -4 -q -c 1 -w 1 last0 >/dev/null 2>&1; then
        message_failure "Cannot ping \"last0\"."
        (( errors++ ))
    else
        message_success "Can ping \"last0\"."
    fi

    # TODO: check we can ping weizmann

    # check we can ping 8.8.8.8
    if ! ping -4 -q -c 1 -w 1 8.8.8.8 > /dev/null 2>&1; then
        message_failure "Cannot ping \"8.8.8.8\" (no Internet ?!?)."
        (( errors++ ))
    else
        message_success "Can ping \"8.8.8.8\", Internet is reachable."
    fi

    return $(( errors ))
}