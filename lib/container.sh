#!/bin/bash

module_include lib/path
module_include lib/macmap

export LAST_CONTAINER_LABEL="LAST-CONTAINER"
export container_selected
export container_reason

function container_init() {
    #
    # A container path can be supplied externally by setting the LAST_CONTAINER_PATH environment
    #  variable.  When the application starts it will automatically add to this path
    #  any mounted USB volumes labeled with the ${LAST_CONTAINER_LABEL} label.
    #
    # TBD: what happens when more than one such volume is mounted (can that happen?!?)
    #

#
# This doesn't work because of order of call of module_include lib/container and parsing of argv
#
#     #
#     # 0. If there is a container_selected in the environment, use it (set in last-tool)
#     #
#     if [ "${container_selected}" ]; then
#         LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_selected}")"
#     fi

    #
    # 1. If we have a labeled local USB disk, it will be first-in-line
    #
    read -r _ _ container_mpoint _ <<< "$( mount -l | grep -w "${LAST_CONTAINER_LABEL}")"
    if [ "${container_mpoint}" ]; then
        LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
        return
    fi

    #
    # 2. According to the local machine's IP address
    #
    local ip_addr=$(macmap_get_local_ipaddr)
    if [ $(hostname -s) = last0 ]; then
        container_mpoint="/last0/data2/LAST-CONTAINER"
        LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
    elif [[ "${ip_addr}" == 10.23.[13].* ]]; then
        # try to force automount of the container
        container_mpoint=/last0/LAST-CONTAINER
        if [ "$(cd ${container_mpoint} >/dev/null 2>&1; echo cata*)" = catalogs ]; then
            LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_mpoint}")"
        fi
#    elif [[ "${ip_addr}" == 10.23.3.* ]]; then
#        if [ "$(hostname -s)" = last12w ]; then
#            container_lab_mpoint="/last12w/data2/LAST-CONTAINER"
#            LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_lab_mpoint}")"
#        else
#            # try to force automount of the container
#            container_lab_mpoint="/mnt/last12w/data2/LAST-CONTAINER"
#            mkdir -p ${container_lab_mpoint}
#            if [ ! "$(cd ${container_mpoint} >/dev/null 2>&1; echo cata*)" = catalogs ]; then
#                mount 10.23.3.24:/last12w/data2/LAST-CONTAINER ${container_lab_mpoint}
#                LAST_CONTAINER_PATH="$(path_append "${LAST_CONTAINER_PATH}" "${container_lab_mpoint}")"
#            fi
#        fi
    fi
}

function container_path() {
    echo "${LAST_CONTAINER_PATH}"
}

#
# Searches for the first LAST-container along the LAST_CONTAINER_PATH
#  that has what we're looking for
#
function container_lookup() {
    local what="${1}"
    local container

    for container in $(path_to_list "${LAST_CONTAINER_PATH}"); do
        if container_has "${container}" "${what}"; then
            echo "${container}"
            return
        fi
    done
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
        local -a releases=( $(cd ${container_path}/matlab ; find -maxdepth 1 -type d -name 'R*' | sed -e 's;^..;;') )
        if [ ${#releases[*]} -gt 0 ]; then
            return 0
        else
            return 1
        fi
        ;;
    
    catalogs)
        if [ -d "${container_path}/catalogs/GAIA/DR3" ] && [ -d "${container_path}/catalogs/MergedCat/V2" ]; then
            return 0
        else
            return 1
        fi
        ;;

    packages)
        local package needed_packages=( nomachine_7.7.4_1_amd64.deb sdk_linux64_21.07.16.tgz wine+CME2.tgz )

        for package in ${needed_packages[*]}; do
            if [ ! -r ${container_path}/packages/${package} ]; then
                return 1
            fi
        done
        return 0
        ;;


    ssh)
        local i
        for i in id_rsa id_rsa.pub id_rsa.pem; do
            if [ ! -r ${container_path}/files/ssh/${i} ]; then
                return 1
            fi
        done
        return 0
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
