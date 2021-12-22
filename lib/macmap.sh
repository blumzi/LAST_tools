#!/bin/bash

module_include lib/message

export _macmap_file=${LAST_ROOT}/files/MACs

function macmap_init() {
    if [ ! -r "${_macmap_file}" ]; then
        message_fatal "${FUNCNAME[0]}: File \"${_macmap_file}\" is not readable."
    fi
}

function macmap_get_local_mac() {
    local -a words

    words=( $(ip -o link show | grep link/ether) )
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
    
    words=( $(macmap_getent "${mac}") ) || return $?
    echo "${words[2]}"
}

function macmap_mac_to_hostname() {
    local mac="${1}"

    if [ ! "${mac}" ]; then
        message_failure "${FUNCNAME[0]}: Missing argument"
        return
    fi
    
    words=( $(macmap_getent "${mac}") ) || return $?
    echo "${words[1]}"
}

function macmap_getent() {
    local mac="${1}"
    local -a words
    
    words=( $(grep -wi "^${mac}" "${_macmap_file}") ) || 
        message_fatal "${FUNCNAME[0]}: No line for mac=${mac} in ${_macmap_file}"

    if [ ${#words[*]} -ne 3 ]; then
        message_fatal "${FUNCNAME[0]} Badly formatted line for mac \"${mac}\ in ${_macmap_file}"
        return
    fi
    echo "${words[@]}"
}

#
# Gets the IP address for the current machine, based on the Ethernet MAC
#
function macmap_get_local_ip_address() {
    macmap_mac_to_ip_address "$( macmap_get_local_mac )"
}

#
# Gets the hostname for the current machine, based on the Ethernet MAC
#
function macmap_get_local_hostname() {
    macmap_mac_to_hostname "$( macmap_get_local_mac )"
}