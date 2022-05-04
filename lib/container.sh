#!/bin/bash

module_include lib/path

export LAST_CONTAINER_LABEL="LAST-CONTAINER"
export selected_container=""

declare mpoint
#
# A container path can be supplied externally by setting the LAST_CONTAINER_PATH environment
#  variable.  When the application starts it will automatically add to this path
#  any mounted USB volumes labeled with the ${LAST_CONTAINER_LABEL} label.
#
# TBD: what happens when more than one such volume is mounted (can that happen?!?)
#
read -r _ _ mpoint _ <<< "$( mount -l | grep "\[${LAST_CONTAINER_LABEL}\]")"
if [ "${mpoint}" ]; then
    LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${mpoint}")"
fi

mpoint=/last0/LAST-CONTAINER
if [ -d ${mpoint}/catalogs ]; then
    LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${mpoint}")"
fi
unset mpoint

function container_path() {
    echo "${LAST_CONTAINER_PATH}"
}

#
# Searches for the first valid LAST-container along the LAST_CONTAINER_PATH
#
function container_lookup() {
    local container

    for container in $(path_to_list "${LAST_CONTAINER_PATH}"); do
        if container_is_valid "${container}"; then
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
        # message_failure "\"${container}\" is not a directory" >&2
        return 1
    fi
    
    if [ ! -d "${container}/catalogs/GAIA/DRE3" ]; then
        # message_failure "Missing \"catalogs/GAIA/DRE3\" in \"${container}\"" >&2
        (( errors++ ))
    fi
    
    if [ ! -d "${container}/catalogs/MergedCat" ]; then
        # message_failure "Missing \"catalogs/MergedCat\" in \"${container}\"" >&2
        (( errors++ ))
    fi

    if [ ! -d "${container}/matlab/R2020b" ]; then
        # message_failure "Missing \"matlab/R2020b\" in \"${container}\"" >&2
        (( errors++ ))
    fi

    local deb
    deb="$( find "${container}"/packages -name 'last-tool-*.deb' )"
    if [ ! "${deb}" ]; then
        # message_failure "Missing \"last-tool\" debian package in \"${container}/packages\"" >&2
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
        if [ -d "${container_path}/catalogs/GAIA/DRE3" ] && [ -d "${container_path}/catalogs/MergedCat/V1" ]; then
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

    At startup, if an USB volume labeled ${LAST_CONTAINER_LABEL} is mounted and is a valid LAST
     container, it is appended to LAST_CONTAINER_PATH.
    
    Possible locations may include:
      - /some/path where a disk labeled ${LAST_CONTAINER_LABEL} is mounted (see mount -l)
      - /last0 - a central container, NFS mounted from last0
      - /some/other/path - A file-system accessible directory

    A directory is a valid LAST container if it contains:
      - A "matlab/R2020b" subdirectory with a valid Matlab installation
      - A "catalogs" subdirectory containing the LAST catalogs
      - A "github-token" file
      - A "last-tool-x.y.z.deb" package in the packages subdirectory
      - A wine.tgz file containing a "Copley Motion" installation
      
EOF
}
