#!/bin/bash

module_include message
module_include deploy

sections_register_section "catalogs" "Handles the LAST catalogs" "filesystems"

export catalogs_local_top
catalogs_local_top="/$(hostname)/data/catsHTM"
export catalogs_container_top
export -a catalogs=( GAIA/DRE3  MergedCat )

function catalogs_init() {
	if [ "${selected_container}" ]; then
		catalogs_container_top="${selected_container}/catalogs"
	fi
}

function catalogs_sync_catalog() {
	local catalog="${1}"
	local -i nfiles files_per_chunk=1000
    local files_list

    files_list=$(mktemp rsync-"${catalog}".XXXXXXXX)	
    rsync -av --info=STATS0 --info=FLIST0 --itemize-changes --dry-run \
        "${catalogs_container_top}/${catalog}" "${catalogs_local_top}/${catalog}" | \
        grep -v '.d..t...... ./' > "${files_list}"
    nfiles=$(wc -l < "${files_list}")

    if (( nfiles == 0 )); then
        message_success "Catalog ${catalog} is synchronized"
        return
    fi

	mkdir -p "${catalogs_local_top}/${catalog}"
    local dir status

    dir=$(mktemp -d rsync-"${catalog}".d.XXXXXXXX)
    pushd "${dir}" || true
    split --lines=${files_per_chunk} < "${files_list}"
    for chunk in x??; do
        message_info "Synchronizing chunk ${chunk} of \"${catalog}\" ($(wc -l < "${chunk}") files) ..."
        rsync -avq --delete --files-from="${chunk}" "${catalogs_container_top}/${catalog}/" "${catalogs_local_top}/${catalog}" &
    done
    wait -fn
    status=${?}
    if (( status == 0 )); then
        message_success "Synchronized ${catalogs_local_top}/${catalog} with ${catalogs_container_top}/${catalog}"
    else
        message_failure "Failed to synchronize ${catalogs_local_top}/${catalog} with ${catalogs_container_top}/${catalog} (status: ${status})"
    fi
    /bin/rm -rf "${dir}" "${files_list}"
}

#
# The staging area for catalogs:
#   euler1:/var/www/html/data (mounted on euler:/data/euler)
#
# euler1:/var/www/html/data  670T  209T  462T  32% /data/euler
#
function catalogs_enforce() {
    local status
    
    if macmap_this_is_last0; then
        message_success "No catalogs on last0"
        return
    fi

	if [ ! "${catalogs_container_top}" ]; then
        message_failure "No LAST container, cannot synchronize catalogs (maybe specify one with --catalog=... ?!?)"
        return
    fi

    mkdir -p "${catalogs_local_top}"

    for catalog in "${catalogs[@]}"; do
		catalogs_sync_catalog "${catalog}" &
    done
	wait
}

function catalogs_check() {
    
    if macmap_this_is_last0; then
        message_success "No catalogs on last0"
        return
    fi

	if [ ! "${catalogs_container_top}" ]; then
        message_failure "No LAST-CONTAINER, cannot synchronize catalogs (maybe specify one with --container=... ?!?)"
        return
    fi

    if [ ! -d "${catalogs_local_top}" ]; then
        message_failure "Missing \"${catalogs_local_top}\""
        return 1
    fi

    for catalog in "${catalogs[@]}"; do
        local -i nfiles

        nfiles=$( rsync -av --info=STATS0 --info=FLIST0 --itemize-changes --dry-run \
            "${catalogs_container_top}/${catalog}" "${catalogs_local_top}/${catalog}" | \
            grep -vc '.d..t...... ./'
            )
        
        if (( nfiles > 0 )); then
            message_warning "Catalog ${catalogs_local_top}/${catalog}: ${nfiles} files differ (with ${catalogs_container_top}/${catalog})"
        else
            message_success "Catalog ${catalogs_local_top}/${catalog} is up-to-date (with ${catalogs_container_top}/${catalog})"
        fi
    done
}

function catalogs_policy() {
    cat <<- EOF

    The LAST project uses the GAIA/DRE3 and the MergedCAT catalogs.  Both need to reside in /data/catsHTM.

    If a LAST-CONTAINER container is available (USB disk, mounted filesystem, etc.):
     - $(ansi_underline "${PROG} check catalogs") - checks that the installed catalogs are in sync with the ones in the container
     - $(ansi_underline "${PROG} enforce catalogs") - synchronizes the catalogs with the ones in the container, installing them if needed.

    If no container is available:
     - ${PROG} check catalogs - (TBD) checks the catalogs hierarchy and checksums against values saved at installation time 

EOF
}
