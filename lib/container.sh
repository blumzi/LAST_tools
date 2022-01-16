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
    local mpoint

    # TBD: we assume only one container is mounted, can there be more?
    read -r _ _ mpoint _ <<< "$( mount -l | grep "\[${LAST_CONTAINER_LABEL}\]")"
    if [ "${mpoint}" ]; then
        LAST_CONTAINER_PATH+=":${mpoint}"
    fi

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
    local -i errors=0

    if [ ! -d "${container}" ]; then
        message_failure "\"${container}\" is not a directory"
        return 1
    fi
    
    if [ ! -d "${container}/catsHTM/GAIA/DRE3" ]; then
        message_failure "Missing \"catsHTM/GAIA/DRE3\" in \"${container}\""
        (( errors++ ))
    fi
    
    if [ ! -d "${container}/catsHTM/MergedCat" ]; then
        message_failure "Missing \"catsHTM/MergedCat\" in \"${container}\""
        (( errors++ ))
    fi
    if [ ! -d "${container}/matlab/R2020b" ]; then
        message_failure "Missing \"matlab/R2020b\" in \"${container}\""
        (( errors++ ))
    fi

    if [ ! -r "${container}/github-token" ]; then
        message_failure "Missing \"github-token\" in \"${container}\""
        (( errors++ ))
    fi

    local deb
    deb="$( find "${container}"/packages -name 'last-tool-*.deb' )"
    if [ ! "${deb}" ]; then
        message_failure "Missing \"last-tool\" debian package in \"${container}/packages\""
        (( errors++ ))
    fi

    return $(( errors ))
}

#
# Checks whether the specified container has the stuff needed by the
#  specified installation section
#
function container_has() {
    local container_path="${1}"
    local section="${2}"

    if [ ! -d "${container_path}" ]; then
        return 1
    fi
    if [ ! "${section}" ]; then
        return 1
    fi

    case "${section}" in

    matlab)
        if [ -d "${container_path}/matlab/R2020b" ]; then
            return 0
        else
            return 1
        fi
        ;;
    
    catalogs)
        if [ -d "${container_path}/catsHTM/GAIA/DRE3" ] && [ -d "${container_path}/catsHTM/MergedCat/V1" ]; then
            return 0
        else
            return 1
        fi
        ;;

    software)
        if [ -r "${container_path}/github-token" ]; then
            return 0
        else
            return 1
        fi
        ;;

    wine)
        if [ -r "${container_path}/wine.tgz" ]; then
            return 0
        else
            return 1
        fi
        ;;

    *)
        return 1
        ;;
    esac
}

function container_policy() {
    cat <<- EOF

    The ${PROG} utility uses LAST containers to manage the local machine's installation.
    One or more containers may be available at any given time. The search order is determined
     by the LAST_CONTAINER_PATH environment variable.
    
    Possible locations may include:
      - /some/path where a disk labeled LAST-CONTAINER is mounted (see mount -l)
      - /last0 - a central container, NFS mounted from last0
      - /some/other/path - A file-system accessible directory

    A directory is a valid LAST container if it contains:
      - A "matlab/R2020b" subdirectory with a valid Matlab installation
      - A "catsHTM" subdirectory containing the LAST catalogs
      - A "github-token" file
      - A "last-tool-x.y.z.deb" package
      - A wine.tgz file containing a "Copley Motion" installation
      
EOF
}