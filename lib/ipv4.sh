#!/bin/bash

#
# Functions for IPv4 address calculations
#

# Get the net part of an address given the CIDR prefix
function ipv4_netpart() {
    local quad="${1}"
    local prefix="${2}"
    local -i u mask
    
    (( mask = ((1 << prefix) - 1) << (32 - prefix) ))
    u=$( ipv4_quad2uint "${quad}" )

    ipv4_uint2quad $(( u & mask))
}

# Get the host part of an address given the CIDR prefix
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

# Create the broadcast address given an IP address and the CIDR prefix
function ipv4_broadcast() {
    local quad="${1}"
    local prefix="${2}"

    local netpart hostpart

    hostpart=$(ipv4_hostpart 255.255.255.255 "${prefix}")
     netpart=$(ipv4_netpart "${quad}" "${prefix}")

    ipv4_uint2quad $(( $(ipv4_quad2uint "${netpart}") | "${hostpart}" ))
}

#
# Create the gateway address given an IP address and the CIDR prefix
# NOTE: We assume the gateway is always host 254
#
function ipv4_gateway() {
    local quad="${1}"
    local prefix="${2}"

    local netpart hostpart=254

    netpart=$(ipv4_netpart "${quad}" "${prefix}")

    ipv4_uint2quad $(( $(ipv4_quad2uint "${netpart}") | "${hostpart}" ))
}

# Transform an IP address from quad notation to an unsigned integer
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

# Transform an IP address from an unsigned integer to quad notation
function ipv4_uint2quad() {
    local -i uint="${1}"
    local -a quad

    for (( i = 3; i >=0 ; i-- )); do
        (( quad[3 - i] = (uint >> (i * 8)) & 0xff ))
    done

    echo "${quad[*]}" | tr ' ' '.'
}
