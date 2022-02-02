#!/bin/bash

module_include lib/message

export _macmap_file

function macmap_init() {
    _macmap_file="$(module_locate files/MACmap)"

    if [ ! "${_macmap_file}" ]; then
        message_warning "${FUNCNAME[0]}: Cannot module_locate \"files/MACmap\" "
    fi
}

function macmap_file() {
    if [ ! "${_macmap_file}" ]; then
        _macmap_file="$(module_locate files/MACmap)"

        if [ ! "${_macmap_file}" ]; then
            message_fatal "${FUNCNAME[0]}: Cannot locate \"files/MACmap\" in LAST_MODULE_INCLUDE_PATH=\"${LAST_MODULE_INCLUDE_PATH}\""
            return
        fi
    fi
    echo "${_macmap_file}"
}

function macmap_get_local_mac() {
    local -a words

    read -r -a words <<< "$(ip -o link show | grep link/ether | grep ': en')"
    for (( i = 0; i < ${#words[*]}; i++ )); do
        if [ "${words[i]}" = "link/ether" ]; then
            echo "${words[i+1]}"
            return
        fi
    done
}

function macmap_mac_to_ip_address() {
    local mac="${1}"
    local -a words

    if [ ! "${mac}" ]; then
        return 1
    fi
    
    read -r -a words <<< "$(macmap_getent_by_mac "${mac}")" || return $?
    echo "${words[1]}"
}

function macmap_mac_to_hostname() {
    local mac="${1}"

    if [ ! "${mac}" ]; then
        return
    fi
    
    read -r -a words <<< "$(macmap_getent_by_mac "${mac}")" || return $?
    echo "${words[2]}"
}

function macmap_getent_by_mac() {
    local mac="${1}"
    local -a words
    local file
    
    if [ ! "${mac}" ]; then
        return
    fi

    file="$(module_locate files/MACmap)"    
    read -r -a words <<< "$(grep -wi "^${mac}" "${file}" )"
    
    if [ ${#words[*]} -eq 0 ]; then
        message_fatal "${FUNCNAME[0]}: Missing mac=${mac} in ${file}"
        return
    fi

    if [ ${#words[*]} -lt 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for mac \"${mac}\" in ${_macmap_file}"
        return
    fi
    echo "${words[@]}"
}

function macmap_getent_by_hostname() {
    local hostname="${1}"
    local -a words
    local file
    
    if [ ! "${hostname}" ]; then
        return
    fi
    
    file="$(module_locate files/MACmap)"  
    
    read -r -a words <<< "$(grep -w "${hostname}" "${file}" )"
    
    if [ ${#words[*]} -eq 0 ]; then
        message_fatal "${FUNCNAME[0]}: Missing hostname=${hostname} in ${file}" >&2
        return
    fi

    if [ ${#words[*]} -lt 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for hostname \"${hostname}\" in ${file}"
        return
    fi
    echo "${words[@]}"
}


function macmap_getent_by_ipaddr() {
    local ipaddr="${1}"
    local -a words
    local file
    
    file="$(module_locate files/MACmap)" 
    
    read -r -a words <<< "$(grep -w "${ipaddr}" "${file}" )"
    
    if [ ${#words[*]} -eq 0 ]; then
        message_fatal "${FUNCNAME[0]}: Missing ipaddr=${ipaddr} in ${file}"
        return
    fi

    if [ ${#words[*]} -lt 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for ipaddr \"${ipaddr}\" in ${file}"
        return
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

    if [ ! "${this_hostname}" ]; then
        return
    fi
    local this_mount=${this_hostname:0:6}
    local this_side=${this_hostname:6:1}
    local peer_side

    if [ "${this_side}" = 'e' ]; then
        peer_side='w'
    elif [ "${this_side}" = 'w' ]; then
        peer_side='e'
    else
        message_fatal "${FUNCNAME[0]}: Bad host name \"${this_hostname}\" for this machine!"
        return
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

function macmap_this_is_last0() {
    if [ "$(macmap_get_local_hostname)" = last0 ]; then
        return 0
    fi
    return 1
}