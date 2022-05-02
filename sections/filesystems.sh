#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include sections/network

sections_register_section "filesystems" "Manages the exporting/mounting of filesystems" "network ubuntu-packages"

export _filesystems_local_hostname

export _filesystems_mount_options="rw,sync,no_root_squash,no_subtree_check"

#
# On some machines the filesystem occupies the whole disk, on others
#  a partition (spanning the whole disk) was created
#
export -A _filesystems_devmap=(
    [/dev/sda]="data1"      # whole device
    [/dev/sdb]="data2"
    [/dev/sdc]="data"
)

function filesystems_init() {
    _filesystems_local_hostname="$(macmap_get_local_hostname)"
    if macmap_this_is_last0; then
        _filesystems_last0=true
    else
        _filesystems_last0=false
    fi
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
    local local_hostname peer_hostname tmp config_file d dev
    local -a entry key

    #
    # Handle local filesystems
    #
    tmp=$(mktemp)
    config_file="/etc/fstab"
    if ${_filesystems_last0}; then
        {
            grep -v "/dev/sd[ab]" "${config_file}"
			echo "/dev/sda /last0/data1  ext4 defaults 0 0"
			echo "/dev/sdb /last0/data2  ext4 defaults 0 0"
        } > "${tmp}"
    else
        local_hostname=$( macmap_get_local_hostname )
         peer_hostname=$( macmap_get_peer_hostname  )

        mkdir -p /"${local_hostname}"/{data,data1,data2} /"${peer_hostname}"/{data1,data2}

        {
            grep -vE "(/dev/sd[abc]|${local_hostname}|${peer_hostname})" ${config_file} | grep -v '^[[:space:]]*$'		# keep non-related lines

            echo ""
            for key in ${!_filesystems_devmap[*]}; do                                       # add our lines
                dev=${key}
                if lsblk "${dev}1" >/dev/null 2>&1; then
                    dev=${dev}1
                fi
                echo "${dev} /${local_hostname}/${_filesystems_devmap[${key}]}  ext4 defaults 0 0"
            done

            # add cross-mount lines
            echo ""
            echo "${peer_hostname}:/${peer_hostname}/data1 /${peer_hostname}/data1 nfs defaults 0 0"
            echo "${peer_hostname}:/${peer_hostname}/data2 /${peer_hostname}/data2 nfs defaults 0 0"
        } > "${tmp}"
    fi
    mv "${tmp}" "${config_file}"
    chmod 644 "${config_file}"
    message_success "Updated \"${config_file}\"."

    tmp=$(mktemp)
    config_file="/etc/exports"
    {
        local line="/usr/local/LAST-CONTAINER " net
        
        for net in $(macmap_last_networks); do
            line+=" ${net}(${_filesystems_mount_options})"
        done
        if ${_filesystems_last0}; then
            grep -v "LAST-CONTAINER" "${config_file}"
            echo "${line}"
        else
            grep -v "^/${local_hostname}/data" "${config_file}"

            echo "/${local_hostname}/data1 ${peer_hostname}(${_filesystems_mount_options})"
            echo "/${local_hostname}/data2 ${peer_hostname}(${_filesystems_mount_options})"
        fi
    } > "${tmp}"
    mv "${tmp}" "${config_file}"
	chmod 644 "${config_file}"
    message_success "Updated \"${config_file}\"."

	systemctl stop autofs
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

    # shellcheck disable=SC2044
    for i in $(find / -maxdepth 1 -name 'last*[0-9]' -type d); do
        find "${i}" -maxdepth 2 -name 'data*' -empty -type d -delete
    done
    find / -maxdepth 1 -name 'last*' -empty -type d -delete

    if mount --all --type ext4; then
        message_success "(Re)mounted the local filesystems"
    else
        message_failure "Failed to (re)mount the local filesystems"
    fi

    if timeout 2 ping -w 1 -c 1 "${peer_hostname}" >&/dev/null; then
        message_info "Mounting filesystems from peer machine \"${peer_hostname}\"."
        mount --all --type nfs &
    else
        message_warning "Backgrounding mounting of filesystems from peer machine \"${peer_hostname}\"."
        mount --all --type nfs &
    fi

    chmod 755 /"${local_hostname}"/data*
    message_success "Changed permission to 755 on exported filesystems /${local_hostname}/data* ... "

    service nfs-kernel-server restart &
    message_success "Restarted NFS kernel server (background)"

    if ! ${_filesystems_last0}; then
        tmp=$(mktemp)
        config_file="/etc/auto.master.d/auto.last0"
        {
            grep -v last0 "${config_file}"
            echo "/mnt/last0/LAST-CONTAINER -rw,hard,bg last0:/last0/data2/LAST-CONTAINER"
        } > "${tmp}"
        mv "${tmp}" "${config_file}"
        chmod 644 "${config_file}"
        mkdir -p /mnt/last0/LAST-CONTAINER

        message_success "Updated autofs (${config_file})."
        systemctl start autofs
    fi
}

function filesystems_check() {
    local -i ret=0

    if ${_filesystems_last0}; then
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
    
        machine:          lastXXe                                lastXXw

        local mounts:   /lastXXe/data                         /lastXXw/data
                        /lastXXe/data1                        /lastXXw/data1
                        /lastXXe/data2                        /lastXXw/data2

        NFS mounts:
                        /lastXXe/data1               NFS->    /lastXXe/data1
                        /lastXXe/data2               NFS->    /lastXXe/data2
                        /lastXXw/data1               <-NFS    /lastXXw/data1
                        /lastXXw/data2               <-NFS    /lastXXw/data2


        machine:          last0                                lastXX[ew]

        autofs mounts:
                        /last0/data2/LAST-CONTAINER  NFS->    /mnt/last0/LAST-CONTAINER

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
        read -r dev _ used avail pcent mpoint <<< "$( df --human-readable --type ext4 2>/dev/null | grep " ${d}$" )"
        if [ "${dev}" ] && [ "${mpoint}" ]; then
            message_success "Local filesystem ${d} is mounted (used: ${used}, avail: ${avail}, percent: ${pcent})"
        else
            message_failure "Local filesystem ${d} is NOT mounted"
            (( ret++ ))
        fi
    done

    # check remote filesystems
    if timeout 2 ping -c 1 -w 1 "${peer_hostname}" >/dev/null 2>&1; then
        for d in /${peer_hostname}/{data1,data2}; do
            read -r dev _ used avail pcent mpoint <<< "$( df --human-readable --type nfs4 2>/dev/null | grep " ${d}$" )"
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
