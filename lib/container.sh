#!/bin/bash

export LAST_CONTAINER_LABEL="LAST-CONTAINER"
export LAST_CONTAINER_PATH=${LAST_CONTAINER_PATH:-/media/ocs/${LAST_CONTAINER_LABEL}}
export selected_container

function container_path() {
    echo "${LAST_CONTAINER_PATH}"
}

#
# Searches for a valid LAST-container along the LAST_CONTAINER_PATH
#
function container_lookup() {
    local container

    for container in ${LAST_CONTAINER_PATH//:/ }; do
        if LAST_TOOL_QUIET=true container_is_valid "${container}"; then
            echo "${container}"
            return
        fi
    done
}

#
# Check if a given path is a valid LAST deployment media container
#
function container_is_valid() {
    declare container="${1}"

    if [ ! -d "${container}" ]; then
        message_failure "\"${container}\" is not a directory"
        return 1
    fi
    
    if [ ! -d "${container}/catsHTM" ]; then
        message_failure "No \"${container}/catsHTM\" subdirectory"
        retrun 1
    fi
    
    if [ ! -d "${container}/matlab/R2020b" ]; then
        message_failure "No \"${container}/matlab/R2020b\" subdirectory"
        retrun 1
    fi

    if [ ! -r "${container}/github-token" ]; then
        message_failure "No \"${container}/github-token\" file"
        retrun 1
    fi

    if [ ! -r "${container}/last-tool*.deb" ]; then
        message_failure "No \"${container}/last-tool\" debian package"
        retrun 1
    fi

    return 0
}

function container_policy() {
    cat <<- EOF

    The ${PROG} utility uses LAST containers to manage the local machine's installation.
    One or more containers may be available at any given time. The search order is determined
     by the LAST_CONTAINER_PATH environment variable.
    
    Possible paths may include:
      - /media/ocs/LAST-CONTAINER - a mounted USB disk
      - /mnt/last0 - an central container, NFS mounted from last0
      - /some/other/path - A file-system accessible directory

    A directory is a valid LAST container if it contains:
      - A "matlab/R2020b" subdirectory with a valid Matlab installation
      - A "catsHTM" subdirectory containing the LAST catalogs
      - A "github-token" file
      - A "last-tool-x.y.z.deb" package
      
EOF
}