#!/bin/bash

module_include message
module_include deploy

sections_register_section "catalogs" "Handles the LAST catalogs" "deploy"

export catalogs_local_top="/data/catsHTM"
export catalogs_deployed_top
export -a catalogs=( GAIAEDR3  MergedCat )

function catalogs_init() {
    catalogs_deployed_top="${selected_container}/catsHTM"
}
#
# The staging area for catalogs:
#   euler1:/var/www/html/data (mounted on euler:/data/euler)
#
# euler1:/var/www/html/data  670T  209T  462T  32% /data/euler
#
function catalogs_enforce() {
    local status
    
    mkdir -p ${catalogs_local_top}

    for catalog in "${catalogs[@]}"; do
        local -i nfiles

        message_info "Synchronizing \"${catalog}\" ..."
        rsync -avq --delete "${catalogs_deployed_top}/${catalog}" "${catalogs_local_top}/${catalog}"
        status=$?
        if (( status = 0 )); then
            message_warning "Synchronized \"${catalog}\"."
        else
            message_success "Failed to synchronize \"${catalog}\" (status=${status})"
        fi
    done
}

function catalogs_check() {

    if [ ! -d "${catalogs_local_top}" ]; then
        message_failure "Missing \"${catalogs_local_top}\""
        return 1
    fi

    for catalog in "${catalogs[@]}"; do
        local -i nfiles

        nfiles=$(rsync -avn "${catalogs_deployed_top}/${catalog}" "${catalogs_local_top}/${catalog}" | grep -c hdf5 )
        if (( nfiles > 0 )); then
            message_warning "Catalog ${catalog}: ${nfiles} differ"
        else
            message_success "Catalog ${catalog} is up-to-date"
        fi
    done
}

function catalogs_policy() {
    cat <<- EOF

    The LAST project uses the GAIA DRE3 and the MergedCAT catalogs.  Both need to reside in /data/catsHTM.

    If a LAST-DEPLOYER container is available (USB disk, mounted filesystem, etc.):
     - $(ansi_underline "${PROG} check catalogs") - checks that the installed catalogs are in sync with the ones in the container
     - $(ansi_underline "${PROG} enforce catalogs") - synchronizes the catalogs with the ones in the container, installing them if needed.

    If no container is available:
     - ${PROG} check catalogs - checks the catalogs hierarchy and checksums against values saved at installation time

EOF
}