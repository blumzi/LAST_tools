#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include sections/network

sections_register_section "filesystems" "Manages the exporting/mounting of filesystems" "network ubuntu-packages"

export _filesystems_local_hostname

export _filesystems_mount_options="rw,no_subtree_check"

function filesystems_init() {
    _filesystems_local_hostname="$(macmap_get_local_hostname)"
}

#
# Cross mounting of filesystems between sibling machines (belonging to same LAST mount)
# Example: Mount last1 has two computers last01e and last01w
#   On: last01e

#       /last01e/data1  - local fs
#       /last01e/data2  - local fs
#       /last01w/data1  - nfs mount from last01w:/last01w/data1
#       /last01w/data2  - nfs mount from last01w:/last01w/data2
#

function filesystems_enforce() {
    local local_hostname peer_hostname tmp config_file d
    local -a entry


    if macmap_this_is_last0; then
        message_success "Nothing to do on \"last0\"."
        return
    fi

    local_hostname=$( macmap_get_local_hostname )
    peer_hostname=$( macmap_get_peer_hostname )

    mkdir -p /"${local_hostname}"/{data,data1,data2} /"${peer_hostname}"/{data1,data2}

    tmp=$(mktemp)
    config_file="/etc/fstab"
    {
        grep -vE "(/dev/sd[abc]|${local_hostname}|${peer_hostname})" ${config_file}
        cat <<- EOF > "${tmp}"

		/dev/sda /${local_hostname}/data1 ext4 defaults 0 0
		/dev/sdb /${local_hostname}/data2 ext4 defaults 0 0
		/dev/sdc /${local_hostname}/data ext4 defaults 0 0

		${peer_hostname}:/${peer_hostname}/data1 /${peer_hostname}/data1 nfs defaults 0 0
		${peer_hostname}:/${peer_hostname}/data2 /${peer_hostname}/data2 nfs defaults 0 0
EOF
    } > "${tmp}"
    mv "${tmp}" "${config_file}"
	chmod 644 "${config_file}"

    tmp=$(mktemp)
    config_file="/etc/exports"
    {
        grep -v "^/${local_hostname}/data" "${config_file}"

        cat <<- EOF > "${tmp}"
		/${local_hostname}/data1 ${peer_hostname}(${_filesystems_mount_options})
		/${local_hostname}/data2 ${peer_hostname}(${_filesystems_mount_options})
EOF
    } > "${tmp}"
    mv "${tmp}" "${config_file}"
	chmod 644 "${config_file}"

	declare -a original_mpoints
	read -r -a original_mpoints <<< "$( find / -maxdepth 2 \( -name data -o -name 'data[12]' \) -type d | grep -vE "(${local_hostname}|${peer_hostname})" )"
	if (( ${#original_mpoints[*]} != 0 )); then
		message_info "Unmounting the original filesystems"
		#
		# unmount the local volumes, originally mounted by the Weizmann installation
		#
		local mpoint
		for mpoint in "${original_mpoints[@]}"; do
			umount -f "${mpoint}" >& /dev/null
			rmdir "${mpoint}"
		done
	fi
    find / -maxdepth 1 -name 'last*' -empty -type d -delete

    message_info "(Re)mounting the local data'*' filesystems"
    mount -all --type ext4

    if ping -w 1 -c 1 "${peer_hostname}" >&/dev/null; then
        message_info "Mounting filesystems from peer machine \"${peer_hostname}\"."
        mount --all --type nfs
    else
        message_warning "Backgrounding mounting of filesystems from peer machine \"${peer_hostname}\"."
        mount --all --type nfs >/dev/null 2>&1 &
    fi

    message_info "Changing permission to 755 on exported filesystems /${local_hostname}/data* ... "
    chmod 755 "/${local_hostname}/data*"

    message_info "Restarting NFS kernel server"
    service nfs-kernel-server restart
}

function filesystems_check() {
    local -i ret=0

    if macmap_this_is_last0; then
        message_success "Nothing to check on last0"
        return 0
    fi

    filesystems_check_config; (( ret += $? ))
    filesystems_check_mounts; (( ret += $? ))

    return $(( ret ))
}

function filesystems_policy() {

    cat <<- EOF

    - Each LAST machine has three data areas: data, data1 and data2, mounted from local disks.
    - The data1 and data2 areas are NFS cross mounted between the sibling machines
    
        machine:          lastXXe                      lastXXw

        local mounts:   /lastXXe/data               /lastXXw/data
                        /lastXXe/data1              /lastXXw/data1
                        /lastXXe/data2              /lastXXw/data2

        NFS mounts:
                        /lastXXe/data1     NFS->    /lastXXe/data1
                        /lastXXe/data2     NFS->    /lastXXe/data2
                        /lastXXw/data1     <-NFS    /lastXXw/data1
                        /lastXXw/data2     <-NFS    /lastXXw/data2

EOF

}

function filesystems_check_config() {
    local config_file d entry
    local -i ret=0
    local local_hostname peer_hostname

    local_hostname=$( macmap_get_local_hostname )
    peer_hostname=$( macmap_get_peer_hostname )

    # check mount points
    for d in /${local_hostname}/{data,data1,data2} /${peer_hostname}/{data1,data2}; do
        if [ -d "${d}" ]; then
            message_success "Directory ${d} exists"
        else
            message_failure "Directory ${d} does not exist"
            (( ret++ ))
        fi
    done

    config_file="/etc/fstab"
    # check /etc/fstab for local filesystems
    for d in /${local_hostname}/{data,data1,data2}; do
        read -r -a entry <<< "$( grep "^/dev.*[[:space:]]*${d}[[:space:]]*ext4[[:space:]]*defaults[[:space:]]*0[[:space:]]*0" "${config_file}" )"
        if [ ${#entry[*]} -eq 6 ]; then
            message_success "Entry for ${d} in ${config_file} exists and is valid"
        else
            message_failure "Missing or botched entry for ${d} in ${config_file}"
            (( ret++ ))
        fi
    done

    # check fstab entries for mounting peer machine's filesystems
    for d in /${peer_hostname}/{data1,data2}; do    
        read -r -a entry <<< "$( grep "^${peer_hostname}:${d}[[:space:]]*${d}[[:space:]]*nfs[[:space:]]*defaults[[:space:]]*0[[:space:]]*0" "${config_file}" )"
        if [ ${#entry[*]} -eq 6 ]; then
            message_success "Entry for ${d} in ${config_file} exists and is valid"
        else
            message_failure "Missing or botched entry for ${d} in ${config_file}"
            (( ret++ ))
        fi
    done

    # check filesytem export entries
    config_file="/etc/exports"
    for d in /${local_hostname}/data{1,2}; do
        read -r -a entry <<< "$( grep "^${d}[[:space:]]*${peer_hostname}(${_filesystems_mount_options})" "${config_file}" )"
        if [ ${#entry[*]} -eq 2 ]; then
            message_success "Entry for ${d} in ${config_file} exists and is valid"
        else
            message_failure "Missing or botched entry for ${d} in ${config_file}"
            (( ret++ ))
        fi
    done

    return $(( ret ))
}

function filesystems_check_mounts() {
    local d dev used avail pcent mpoint
    local -i ret=0
    local local_hostname peer_hostname

    local_hostname=$( macmap_get_local_hostname )
    peer_hostname=$( macmap_get_peer_hostname )

    # check local filesystems
    for d in /${local_hostname}/{data,data1,data2}; do
        read -r dev _ used avail pcent mpoint <<< "$( df --human-readable --type ext4 | grep " ${d}$" )"
        if [ "${dev}" ] && [ "${mpoint}" ]; then
            message_success "Local filesystem ${d} is mounted (used: ${used}, avail: ${avail}, percent: ${pcent})"
        else
            message_failure "Local filesystem ${d} is NOT mounted"
            (( ret++ ))
        fi
    done

    # check remote filesystems
    if ping -c 1 -w 1 "${peer_hostname}" >/dev/null 2>&1; then
        for d in /${peer_hostname}/{data1,data2}; do
            read -r dev _ used avail pcent mpoint <<< "$( df --human-readable --type nfs4 | grep --quiet " ${d}$" )"
            if [ "${dev}" ] && [ "${mpoint}" ]; then
                message_success "Remote filesystem ${d} is mounted (used: ${used}, avail: ${avail}, percent: ${pcent})"
            else
                message_failure "Remote filesystem ${d} is NOT mounted"
                (( ret++ ))
            fi
        done
    else
        message_warning "Peer machine \"${peer_hostname}\" does not answer to ping"
        (( ret++ ))
    fi

    return $(( ret ))
}
