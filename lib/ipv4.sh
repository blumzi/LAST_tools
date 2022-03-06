#!/bin/bash

#
# Functions for IPv4 address calculations
#

function ipv4_netpart() {
    local quad="${1}"
    local prefix="${2}"
    local -i u mask
    
    (( mask = ((1 << prefix) - 1) << (32 - prefix) ))
    u=$( ipv4_quad2uint "${quad}" )

    ipv4_uint2quad $(( u & mask))
}

function ipv4_hostpart() {
    local quad="${1}"
    local prefix="${2}"

    local -i mask u
    local -a q

    u=$(ipv4_quad2uint "${quad}")
    mask=$(ipv4_quad2uint "$(ipv4_netpart "${quad}" "${prefix}")")

    read -r -a q <<< "$(ipv4_uint2quad $(( u & ~mask )) | tr '.' ' ')"
    while (( q[0] == 0 )); do
        # shellcheck disable=SC2184
        unset q[0]
        read -r -a q <<< "${q[*]}"
    done
    echo "${q[*]}" | tr ' ' '.'
}

function ipv4_quad2uint() {
    local quad="${1}"
    # shellcheck disable=SC2206
    local -a q=( ${quad//./ } )
    local -i uint=0

    for (( i = 0; i < 4; i++ )); do
        (( uint <<= 8 ))
        (( uint |= q[i] ))
    done

    echo "${uint}"
}

function ipv4_uint2quad() {
    local -i uint="${1}"
    local -a quad

    for (( i = 0; i < 4; i++ )); do
        (( quad[i] = (uint >> (3 - i) * 8) & 0xff ))
    done

    echo "${quad[*]}" | tr ' ' '.'
}