#!/bin/bash

#
# LAST deployment disks will be labeled with LABEL=LAST-DEPLOYER
# Ubuntu will mount an USB disk on /media/<user>/<fs-label>
# In our case: user=ocs, fs-label=LAST-DEPLOYER (max: 16 bytes)
#
function deploy_media_dir() {
    local path top
    local label="LAST-DEPLOYER"

    top="/media/ocs/${label}"
    if deploy_is_valid_media "${top}"; then
        echo "${top}"
        return
    fi

    for path in ${LAST_BASH_INCLUDE_PATH[*]//:/ }; do
        top="${path}/files/${label}"
        if deploy_is_valid_media "${top}"; then
            echo "${top}"
            return
        fi
    done
}

function deploy_is_valid_media() {
    declare path="${1}"

    if [ -d "${path}" ] && [ -d "${path}/matlab" ] && [ -d "${path}/catalogs" ]; then
        return 0
    fi
    return 1
}