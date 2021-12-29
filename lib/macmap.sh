#!/bin/bash

module_include lib/message

function macmap_init() {
    :
}

function macmap_file() {
    if [ ! "${_macmap_file}" ]; then
        _macmap_file="$(module_locate files/MACmap)"

        if [ ! "${_macmap_file}" ]; then
            message_fatal "${FUNCNAME[0]}: Cannot locate \"files/MACmap\" in LAST_BASH_INCLUDE_PATH=\"${LAST_BASH_INCLUDE_PATH}\""
        fi
    fi
    echo "${_macmap_file}"
}

function macmap_get_local_mac() {
    local -a words

    read -r -a words <<< "$(ip -o link show | grep link/ether)"
    if [ ${#words[*]} -ne 19 ]; then
        message_fatal "${FUNCNAME[0]}: Cannot get MAC address of local Ethernet (${#words[*]}, ${words[*]})"
        return
    fi
    echo "${words[16]% }"
}

function macmap_mac_to_ip_address() {
    local mac="${1}"
    local -a words

    if [ ! "${mac}" ]; then
        message_failure "${FUNCNAME[0]}: Missing argument"
        return
    fi
    
    read -r -a words <<< "$(macmap_getent_by_mac "${mac}")" || return $?
    echo "${words[2]}"
}

function macmap_mac_to_hostname() {
    local mac="${1}"

    if [ ! "${mac}" ]; then
        message_failure "${FUNCNAME[0]}: Missing argument"
        return
    fi
    
    read -r -a words <<< "$(macmap_getent_by_mac "${mac}")" || return $?
    echo "${words[1]}"
}

function macmap_getent_by_mac() {
    local mac="${1}"
    local -a words
    local file
    
    file="$(module_locate files/MACmap)"    
    read -r -a words <<< "$(grep -wi "^${mac}" "${file}" )" || 
        message_fatal "${FUNCNAME[0]}: Missing mac=${mac} in ${file}"

    if [ ${#words[*]} -ne 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for mac \"${mac}\ in ${_macmap_file}"
    fi
    echo "${words[@]}"
}

function macmap_getent_by_hostname() {
    local hostname="${1}"
    local -a words
    local file
    
    file="$(module_locate files/MACmap)"  
    
    read -r -a words <<< "$(grep -w "${hostname}" "${file}" )" || 
        message_fatal "${FUNCNAME[0]}: Missing hostname=${hostname} in ${file}"

    if [ ${#words[*]} -ne 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for hostname \"${hostname}\ in ${file}"
    fi
    echo "${words[@]}"
}


function macmap_getent_by_ipaddr() {
    local ipaddr="${1}"
    local -a words
    
    file="$(module_locate files/MACmap)" 
    
    read -r -a words <<< "$(grep -w "${ipaddr}" "${file}" )" || 
        message_fatal "${FUNCNAME[0]}: Missing ipaddr=${ipaddr} in ${file}"

    if [ ${#words[*]} -ne 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for ipaddr \"${ipaddr}\ in ${file}"
    fi
    echo "${words[@]}"
}
#
# Gets the IP address for the current machine, based on the Ethernet MAC
#
function macmap_get_local_ipaddr() {
    macmap_mac_to_ip_address "$( macmap_get_local_mac )"
}

#
# Gets the hostname for the current machine, based on the Ethernet MAC
#
function macmap_get_local_hostname() {
    macmap_mac_to_hostname "$( macmap_get_local_mac )"
}

#
# Gets the peer machine's hostname using the local machine's hostname
#
function macmap_get_peer_hostname() {
    local this_hostname

    this_hostname="$( macmap_get_local_hostname )"
    local this_mount=${this_hostname:0:6}
    local this_side=${this_hostname:6:1}
    local peer_side

    if [ "${this_side}" = 'e' ]; then
        peer_side='w'
    elif [ "${this_side}" = 'w' ]; then
        peer_side='e'
    else
        message_fatal "${FUNCNAME[0]}: Bad host name \"${this_hostname}\" for this machine!"
    fi

    echo "${this_mount}${peer_side}"
}

function macmap_get_peer_ipaddr() {
    local network_peer_hostname
    local -a words

    network_peer_hostname=$(macmap_get_peer_hostname)
    read -r -a words <<< "$(macmap_getent_by_hostname "${network_peer_hostname}")"

    echo "${words[2]}"
}