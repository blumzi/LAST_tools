#!/bin/bash

#
# Theory of operation:
#
# A <LAST-container> contains:
#  - Matlab installation packages
#  - The LAST management too package (.deb)
#  - All the catalogs
#
# In a typical deployment situation, computers will be installed
#  from an external USB disk containing at least one <LAST-container>
#
# The USB external disk's label will be (by convention) "LAST-DEPLOYER"
# When attached to the computer, the disk will be mounted on /media/ocs/LAST-DEPLOYER
#
# Until we actually have such installation disks, we simulate their content
#  with directories in the LAST_BASH_INCLUDE_PATH
#

#
# Searches for a valid LAST-container.
# Preferes the USB mount point but will settle for a valid 
#  container on the LAST_BASH_INCLUDE_PATH
#
function deploy_container() {
    local path top
    local label="LAST-DEPLOYER"

    top="/media/ocs/${label}"
    if deploy_is_valid_container "${top}"; then
        echo "${top}"
        return
    fi

    for path in ${LAST_BASH_INCLUDE_PATH[*]//:/ }; do
        top="${path}/files/${label}"
        if deploy_is_valid_container "${top}"; then
            echo "${top}"
            return
        fi
    done
}

#
# Check if a given path is a valid LAST deployment media container
#
function deploy_is_valid_container() {
    declare path="${1}"

    if [ -d "${path}" ] && [ -d "${path}/matlab" ] && [ -d "${path}/catsHTM" ]; then
        return 0
    fi
    return 1
}