#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "hostname" "Manages stuff related to the machine's host name"

function hostname_enforce() {
    local this_hostname

    this_hostname=$( macmap_get_local_hostname )

    if ! hostname_is_valid "${this_hostname}"; then
        message_failure "Invalid hostname \"${this_hostname}\""
        return
    fi

    if hostnamectl --static "${this_hostname}"; then
        message_success "Hostname set to ${this_hostname}"
    else
        message_failure "Could not set hostname to \"${this_hostname}\""
    fi

    #
    # Create a fresh /etc/hosts
    #
    local tmp

    tmp=$(mktemp)
    {
        echo -e "127.0.0.1\tlocalhost ${this_hostname}"
        echo -e "127.0.1.1\t${this_hostname}"
        echo ""

        local -a words
        while read -r -a words; do
            echo -e "${words[2]}\t${words[1]}"
        done < <( grep 10.23 "$(macmap_file)")

        cat << EOF
        # The following lines are desirable for IPv6 capable hosts
        ::1     ip6-localhost ip6-loopback
        fe00::0 ip6-localnet
        ff00::0 ip6-mcastprefix
        ff02::1 ip6-allnodes
        ff02::2 ip6-allrouters

        132.77.100.5 ntp.weizmann.ac.il

EOF

    } > "${tmp}"
    mv "${tmp}" /etc/hosts
    message_success "Create a canonical \"/etc/hosts\" file."
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
    read -r -a hostnames <<< <( grep '^127.0.0.1' /etc/hosts )
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

    if [ "${name}" != last0 ] && [[ "${name}" != last[012][0-9][ew] ]]; then
        return 1
    fi

    local mount_id
    mount_id=${name#last}
    mount_id=${mount_id%[ew]}
    mount_id=$(( mount_id ))

    if (( mount_id == 20 )); then
        return 0    # dummy for testing
    fi

    (( mount_id < 1 || mount_id > 12 )) || return 1

    return 0
}