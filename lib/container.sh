#!/bin/bash

module_include lib/path
module_include lib/macmap

export LAST_CONTAINER_LABEL="LAST-CONTAINER"
export container_mpoint

#
# A container path can be supplied externally by setting the LAST_CONTAINER_PATH environment
#  variable.  When the application starts it will automatically add to this path
#  any mounted USB volumes labeled with the ${LAST_CONTAINER_LABEL} label.
#
# TBD: what happens when more than one such volume is mounted (can that happen?!?)
#

# 0. If there is a selected_container in the environment, use it (set in last-tool)
if [ "${selected_container}" ]; then
    LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${selected_container}")"
fi

# 1. If we have a local USB disk, it will be first-in-line
read -r _ _ container_mpoint _ <<< "$( mount -l | grep "\[${LAST_CONTAINER_LABEL}\]")"
if [ "${container_mpoint}" ]; then
    LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
fi

ip_addr=$(macmap_get_local_ipaddr)
if [ $(hostname -s) = last0 ]; then
    container_mpoint="/last0/data2/LAST-CONTAINER"
    LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
elif [[ "${ip_addr}" == 10.23.1.* ]]; then
    # try to force automount of the container
    container_mpoint=/last0/LAST-CONTAINER
    if [ "$(cd ${container_mpoint} >/dev/null 2>&1; echo cata*)" = catalogs ]; then
        LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
    fi
elif [[ "${ip_addr}" == 10.23.3.* ]]; then
    if [ "$(hostname -s)" = last12w ]; then
        LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "/last12w/data2/LAST-CONTAINER")"
    else
        # try to force automount of the container
        container_mpoint=/last12w/LAST-CONTAINER
        if [ "$(cd ${container_mpoint} >/dev/null 2>&1; echo cata*)" = catalogs ]; then
            LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
        fi
    fi
fi
unset container_mpoint ip_addr

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
