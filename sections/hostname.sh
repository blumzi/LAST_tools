#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "hostname" "Manages stuff related to the machine's host name"

function hostname_enforce() {
    local this_hostname

    if [ ! "$(macmap_file)" ]; then
        message_fatal "Missing MACmap file"
        return
    fi

    this_hostname=$( macmap_get_local_hostname )

    if ! hostname_is_valid "${this_hostname}"; then
        message_failure "Invalid hostname \"${this_hostname}\""
        return
    fi

    if hostnamectl set-hostname "${this_hostname}"; then
        message_success "Hostname set to ${this_hostname}"
    else
        message_failure "Could not set hostname to \"${this_hostname}\""
    fi

    #
    # Create a fresh /etc/hosts
    #
    local tmp ipaddr aliases

    tmp=$(mktemp)
    {
        echo -e "127.0.0.1\tlocalhost ${this_hostname}"
        echo -e "127.0.1.1\t${this_hostname}"
        echo ""

        while read -r _ ipaddr aliases; do
            echo -e "${ipaddr}\t${aliases}"
        done < <( util_uncomment "$(macmap_file)" | grep 10.23 )

        cat <<- EOF

# The following lines are desirable for IPv6 capable hosts
::1             ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

# Pre-defined hosts
132.77.100.5    ntp.weizmann.ac.il
10.23.1.40      skycam
10.23.1.222     rpi-ntp
		
EOF

    } > "${tmp}"
    mv "${tmp}" /etc/hosts
    chmod 644 /etc/hosts
    message_success "Created a canonical \"/etc/hosts\" file."
}

function hostname_make_name() {
    local mount=$(( ${1} )) # transform to integer
    local side=${2}

    if [ ${mount} -lt 1 ] || [ ${mount} -gt 24 ]; then
        message_fatal "${FUNCNAME[0]}: Bad mount number \"${mount}\" (should be 1..24)"
    fi
    if [ "${side}" != 'e' ] && [ "${side}" != 'w' ]; then
        message_fatal "${FUNCNAME[0]}: Bad side \"${side}\" (should be 'e' or 'w')"
    fi
    
    printf "last%02d%s" ${mount} "${side}"
}

function hostname_check() {
    local this_hostname

    this_hostname="$( macmap_get_local_hostname )"

    if ! hostname_is_valid "${this_hostname}"; then
        message_failure "Invalid hostname \"${this_hostname}\""
        return
    fi

    # Check if the current host's name is as expected
    local current_hostname
    current_hostname="$(hostname)"

    if [ "${this_hostname}" = "${current_hostname}" ]; then
        message_success "The hostname is \"${current_hostname}\""
    else
        message_failure "The hostname is \"${current_hostname}\" instead of \"${this_hostname}\""
    fi

    if hostname_is_valid "${current_hostname}"; then
        message_success "The hostname \"${current_hostname}\" is a valid LAST hostname"
    else
        message_failure "The hostname \"${current_hostname}\" is not a valid LAST hostname"
    fi

    local -a hostnames
    hostnames=( last0 )
    for ((mount = 1; mount <= 12; mount++)); do
        for side in 'e' 'w'; do
            hostnames+=( "$(hostname_make_name "${mount}" "${side}")" )
        done
    done

    local -a missing
    for hostname in "${hostnames[@]}"; do
        grep -wq "${hostname}" /etc/hosts >/dev/null || missing+=( "${hostname}" )  
    done
    if [ ${#missing[*]} -gt 0 ]; then        
        message_failure "Missing entries for hostname(s) \"${missing[*]}\" in /etc/hosts"
    else
        message_success "All LAST hosts have entries in /etc/hosts."
    fi

    #
    # the hostname should be an alias of localhost (127.0.0.1)
    #
    local found=false
    read -r -a hostnames <<< "$( grep '^127.0.0.1' /etc/hosts )"
    for (( i = 1; i < ${#hostnames[*]}; i++)); do
        if [ "${hostnames[i]}" = "${this_hostname}" ]; then
            found=true
            break
        fi
    done

    if ${found}; then
        message_success "${this_hostname} is an alias of 127.0.0.1 (localhost)"
    else
        message_failure "${this_hostname} is not an alias of 127.0.0.1 (localhost)"
    fi
}

#
# Checks conformity to the LAST host naming convention
#  Valid names are:
#    last0: master
#    lastXXY: where XX (mount id) is 01..12 and Y (side id) is 'e' or 'w'
#
function hostname_is_valid() {
    local name="${1}"

    if [ "${name:0:4}" != last ]; then
        return 1
    fi

    if [ "${name}" = last0 ]; then
        return 0
    fi

    if [[ "${name}" != last[012][0-9][ew] ]]; then
        return 1
    fi

    local mount_id
    mount_id=${name#last}
    mount_id=${mount_id%[ew]}
    mount_id=$(( ${mount_id##0} ))

    if (( mount_id == 20 )); then
        return 0    # dummy for testing
    fi

    (( mount_id < 1 || mount_id > 12 )) && return 1

    return 0
}

function hostname_policy() {
    cat <<- EOF

    Valid LAST host names are:
    - last{01..12}{e|w} for each of the 12 mounts, where 'e' and 'w' denote the East 
       and the West machines respectively
    - last0 is the LAST master machine
    - pswitch{01..12}{e|w} for the IP controlled power switches (two per mount)

    We currently do not use a dynamic name service (DNS) so the machine names are statically
     mapped in /etc/hosts on each of the LAST machines.

    The hostname <=> ipaddress mapping is derived from the MACmap file ($(macmap_file))

    - The local machine's name must also be an alias for the localhost.
    - The /etc/hosts file must have mappings for:
      - The last0 master machine
      - All the LAST machines, for all the LAST mounts
      - All the IP controlled power switches (two per mount)
      - The roofcontrol controller

EOF
}
