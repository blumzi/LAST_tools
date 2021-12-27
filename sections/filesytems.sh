#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include sections/network

sections_register_section "filesystems" "Manages the exporting/mounting of filesystems"

#
# Cross mounting of filesystems between sibling machines (belonging to same LAST mount)
# Example: Mount last1 has two computers last01e and last01w
#   On: last01e
#       /last01e/data1  - local fs
#       /last01e/data2  - local fs
#       /last01w/data1  - nfs mount from last01w:/last01w/data1
#       /last01w/data2  - nfs mount from last01w:/last01w/data2
#

function filesystems_start() {
    message_info "Starting NFS kernel server"
    service nfs-kernel-server restart
    
    message_info "Mounting all the network filesystems"
    mount -a -t nfs
}

function filesystems_configure() {
    local local_hostname peer_hostname tmp config_file d
    local -a entry

    local_hostname=$( macmap_get_local_hostname )
    peer_hostname=$( macmap_get_peer_hostname )
    tmp=$(mktemp)

    mkdir -p /"${local_hostname}"/data{1,2} /"${peer_hostname}"/data{1,2}

    config_file="/etc/fstab"
    for d in 1 2; do    
        read -r -a entry <<< "$( grep "^${peer_hostname}:${peer_hostname}/data${d}" "${config_file}" )"
        if [ ${#entry} -ne 6 ] || [ "${entry[1]}" != "/${peer_hostname}/data${d}" ] || [ "${entry[2]}" != nfs ]; then
            message_info "Creating ${config_file} entry for ${peer_hostname}/data{$d} ..."
            {
                grep -v "^${peer_hostname}/data${d}" "${config_file}"
                echo "${peer_hostname}:${peer_hostname}/data${d} /${peer_hostname}/data${d} nfs defaults 0 0"
            } > "${tmp}"
            mv "${tmp}" "${config_file}"
        else
            message_success "${config_file} already has an entry for ${peer_hostname}:/${peer_hostname}/data${d}"
        fi
    done

    config_file="/etc/exports"
    for d in 1 2; do
        read -r -a entry <<< "$( grep "^/data${d}" "${config_file}" )"
        if [ ${#entry[*]} -ne 2 ] || [ "${entry[1]}" != "${network_netpart}/${network_prefix}" ]; then
            message_info "Creating ${config_file} entry for /data{$d} ..."
            {
                grep -v "^/data${d}" "${config_file}"
                echo "/data{$d} ${network_netpart}/${network_prefix}"
            } > "${tmp}"
            mv "${tmp}" "${config_file}"
        else
            message_success "${config_file} already has an entry for /data${d}"
        fi
    done
}

function filesystems_check() {
    local local_hostname peer_hostname tmp config_file d
    local -a entry

    local_hostname=$( macmap_get_local_hostname )
    peer_hostname=$( macmap_get_peer_hostname )

    # check fstab entries for mounting peer machine's filesystems
    config_file="/etc/fstab"
    for d in 1 2; do    
        read -r -a entry <<< "$( grep "^${peer_hostname}:${peer_hostname}/data${d}" "${config_file}" )"
        if [ ${#entry} -eq 6 ] && [ "${entry[1]}" = "/${peer_hostname}/data${d}" ] && [ "${entry[2]}" = nfs ]; then
            message_success "${config_file} has an entry for ${peer_hostname}:/${peer_hostname}/data${d}"
        else
            message_failure "${config_file} does not have an entry for ${peer_hostname}:/${peer_hostname}/data${d}"
        fi
    done

    # check filesytem export entries
    config_file="/etc/exports"
    for d in 1 2; do    
        read -r -a entry <<< "$( grep "^${peer_hostname}/data${d}" "${config_file}" )"
        if [ ${#entry} -eq 6 ] && [ "${entry[1]}" = "/${peer_hostname}/data${d}" ] && [ "${entry[2]}" = nfs ]; then
            message_success "${config_file} has an entry for ${peer_hostname}:/${peer_hostname}/data${d}"
        else
            message_failure "${config_file} does not have an entry for ${peer_hostname}:/${peer_hostname}/data${d}"
        fi
    done

    # check that we have the remote filesystems mounted
    for d in 1 2; do
        if [ "$( mount -t nfs | grep -qc "${peer_hostname}:/data${d} on /${peer_hostname}/data${d}")" = 1 ]; then
            message_success "${peer_hostname}:/data${d} is mounted on /${peer_hostname}/data${d}"
        else
            message_failure "${peer_hostname}:/data${d} is not mounted on /${peer_hostname}/data${d}"
        fi
    done
}