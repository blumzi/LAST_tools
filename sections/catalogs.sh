#!/bin/bash

module_include message
module_include deploy
module_include container

trap cleanup SIGINT SIGTERM

sections_register_section "catalogs" "Handles the LAST catalogs" "filesystems network"

export catalogs_local_top
catalogs_local_top="/$(hostname)/data/catsHTM"
export catalogs_container_top
export -a catalogs=( GAIA/DR3 MergedCat/V2 )
export _catalogs_source=""

function cleanup() {
	/bin/rm -rf /tmp/rsync-*${$}*
}

function catalogs_init() {
    # shellcheck disable=SC1090
    source "$(module_locate sections/network.sh)"
    network_set_defaults
    local container

    if [ "${selected_container}" ]; then
        container="${selected_container}"
    else
        container="$(container_lookup)"
        if [ ! "${container}" ]; then
            return
        fi
    fi

    catalogs_container_top="${container}/catalogs"
}

#
# _catalogs_rsync_command GAIA/DRE3 --dry-run
#
function _catalogs_rsync_command() {
    local catalog="${1}"
    shift
    local -a args=( "${@}" )
    local src

    src="${catalogs_container_top}/${catalog}/"
    if [ -d "${src}" ]; then
        echo "rsync ${args[*]} --exclude zzOld --exclude zz1 --exclude oldVer --info=STATS0 --info=FLIST0 --itemize-changes ${src} ${catalogs_local_top}/${catalog}"
    elif [[ "${network_netpart}" == 10.23.3.* ]] && ping -w 1 -c 1 euler1 >/dev/null 2>&1 ; then
        src="blumzi@euler1:/var/www/html/data/catsHTM/${catalog}/"
        echo "su ocs -c \"rsync ${args[*]} --exclude zzOld --exclude zz1 --exclude oldVer --info=STATS0 --info=FLIST0 --itemize-changes ${src} ${catalogs_local_top}/${catalog}\""
    else
        message_fatal "No source for catalog ${catalog}"
    fi
    echo "${src}" > /tmp/_catalogs_rsync_command.src
}

function catalogs_sync_catalog() {
	local catalog="${1}"
	local -i nfiles files_per_chunk=1000
    local files_list no_slashes_catalog

    no_slashes_catalog=$( echo "${catalog}" | tr / _)
    files_list=/tmp/rsync-"${no_slashes_catalog}".${$}
    eval "$(_catalogs_rsync_command "${catalog}"/ -av --dry-run) | \
	    grep -v '\.\/' | \
	    grep -v '^directory$' | \
	    sed -e 's;^\.GAIA;GAIA;' | \
	    cut -d ' ' -f2 > ${files_list}"
    nfiles=$(wc -l < "${files_list}")

    if (( nfiles == 0 )); then
        message_success "Catalog ${catalog} is synchronized"
        return
    fi

	mkdir -p "${catalogs_local_top}/${catalog}"
    local dir status

    dir=${files_list}.d
    mkdir -p "${dir}"
    pushd "${dir}" >&/dev/null || true
    split --lines=${files_per_chunk} < "${files_list}"
    local chunk_no=0
    for chunk in x??; do
	    message_info "Synchronizing chunk #$((chunk_no++)) of \"${catalog}\" ($(wc -l < "${chunk}") files) ..."
        eval "$(_catalogs_rsync_command ${catalog} -avq --files-from="${chunk}" ) 2>/dev/null" &
    done
    wait -fn
    status=${?}
    if (( status == 0 )); then
        message_success "Synchronized $(< /tmp/_catalogs_rsync_command.src) with ${catalogs_container_top}/${catalog}"
    else
        message_failure "Failed to synchronize $(< /tmp/_catalogs_rsync_command.src) with ${catalogs_container_top}/${catalog} (status: ${status})"
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
    local tmp_nfiles
    tmp_nfiles=$(mktemp)
    local src

    if macmap_this_is_last0; then
        message_success "No catalogs on last0"
        return
    fi

    if [ ! -d "${catalogs_local_top}" ]; then
        message_failure "Missing \"${catalogs_local_top}\""
        return 1
    fi

    for catalog in "${catalogs[@]}"; do
        local -i nfiles
        local cmd

        cmd="$(_catalogs_rsync_command "${catalog}"  -a --dry-run) | grep -v '\.\/' | grep -v '^directory$' | wc -l"
        eval "${cmd} > ${tmp_nfiles}"

        nfiles="$(< "${tmp_nfiles}")"
        src="$(< /tmp/_catalogs_rsync_command.src)"
        
        if (( nfiles > 0 )); then
            message_warning "Catalog ${src%/}: ${nfiles} files differ (with ${catalogs_local_top}/${catalog})"
        else
            message_success "Catalog ${src%/} is up-to-date (with ${catalogs_local_top}/${catalog})"
        fi
    done
    /bin/rm "${tmp_nfiles}" /tmp/_catalogs_rsync_command.src
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
