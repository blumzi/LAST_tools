#!/bin/bash

module_include message
module_include deploy
module_include container
module_include user

trap cleanup SIGINT SIGTERM

sections_register_section "catalogs" "Handles the LAST catalogs" "filesystems network"

export catalogs_local_top

if macmap_this_is_last0; then
    catalogs_local_top="$(echo ~${user_name})/matlab"
else
    catalogs_local_top="/$(hostname)/data/catsHTM"
fi

export catalogs_container_top

eval user_catalogs_destination="~${user_name}/matlab"

if macmap_this_is_last0; then
    #
    # Catalogs for last0
    #
    user_catalogs_source="/last0/data2/LAST-CONTAINER/catalogs"

    export -A catalog_sources=(
        [data]="${user_catalogs_source}"
    )

    export -A catalog_destinations=(
        [data]="${user_catalogs_destination}"
    )
else
    global_catalogs_destination="/$(hostname)/data/catsHTM"
    global_catalogs_source="$(container_lookup catalogs)/catalogs"
    user_catalogs_source="/last0/LAST-CONTAINER/catalogs"

    #
    # Catalogs for all other LAST machines
    #
    export -A catalog_sources=(
        [GLADE/v1]="${global_catalogs_source}"
        [QSO/Flesch2021]="${global_catalogs_source}"
        [MergedCat/V2]="${global_catalogs_source}"
        [GAIA/DR3extraGal]="${global_catalogs_source}"
        [GAIA/DR3var]="${global_catalogs_source}"
        [GAIA/DR3]="${global_catalogs_source}"
        [PCG]="${global_catalogs_source}"
        [data]="${user_catalogs_source}"
    )

    export -A catalog_destinations=(
        [GLADE/v1]="${global_catalogs_destination}"
        [QSO/Flesch2021]="${global_catalogs_destination}"
        [MergedCat/V2]="${global_catalogs_destination}"
        [GAIA/DR3extraGal]="${global_catalogs_destination}"
        [GAIA/DR3var]="${global_catalogs_destination}"
        [GAIA/DR3]="${global_catalogs_destination}"
        [PCG]="${global_catalogs_destination}"
        [data]="${user_catalogs_destination}"
    )
fi
export -a relevant_catalogs=( $(echo "${!catalog_sources[@]}" | tr ' ' '\n' | sort | tr '\n' ' ' ) )

function cleanup() {
	/bin/rm -rf /tmp/rsync-*${$}*
}

function catalogs_init() {
    # shellcheck disable=SC1090
    source "$(module_locate sections/network.sh)"
    network_set_defaults
}

#
# _catalogs_rsync_command GAIA/DRE3 --dry-run
#
function _catalogs_rsync_command() {
    local catalog="${1}"
    shift
    local -a args=( "${@}" )
    local src dst local_top

    if [[ " ${relevant_catalogs[*]} " != *" ${catalog} "* ]]; then
        message_fatal "Catalog $(ansi_underline ${catalog}) not relevant to this machine, relevant catalogs: ${relevant_catalogs[*]}"
    fi

    src=${catalog_sources[${catalog}]}/${catalog}
    dst=${catalog_destinations[${catalog}]}/${catalog}

    if [ -d "${src}" ]; then
        echo "rsync ${args[*]} --exclude zzOld --exclude zz1 --exclude oldVer --info=STATS0 --info=FLIST0 --itemize-changes ${src} ${dst}"
    elif [[ "${network_netpart}" == 10.23.3.* ]] && ping -w 1 -c 1 euler1 >/dev/null 2>&1 ; then
        src="blumzi@euler1:/var/www/html/data/catsHTM/${catalog}/"
        echo "su ocs -c \"rsync ${args[*]} --exclude zzOld --exclude zz1 --exclude oldVer --info=STATS0 --info=FLIST0 --itemize-changes ${src} ${dst}"
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
        message_success "Synchronized $(< /tmp/_catalogs_rsync_command.src) with ${catalog_destinations[${catalog}]}/${catalog}"
    else
        message_failure "Failed to synchronize $(< /tmp/_catalogs_rsync_command.src) with ${catalog_destinations[${catalog}]}/${catalog} (status: ${status})"
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
    
	if [ ! "${catalogs_container_top}" ]; then
        message_failure "No LAST container, cannot synchronize catalogs (maybe specify one with --catalog=... ?!?)"
        return
    fi

    mkdir -p "${catalogs_local_top}"

    message_info "The following catalogs will be enforced: ${relevant_catalogs[*]}"
    for catalog in "${relevant_catalogs[@]}"; do
		catalogs_sync_catalog "${catalog}" &
    done
	wait
}

function catalogs_check() {
    local tmp_nfiles
    tmp_nfiles=$(mktemp)
    local src

    if [ ! -d "${catalogs_local_top}" ]; then
        message_failure "Missing \"${catalogs_local_top}\""
        return 1
    fi

    message_info "The following catalogs will be checked: ${relevant_catalogs[*]}"
    for catalog in "${relevant_catalogs[@]}"; do
        local -i nfiles
        local cmd

        cmd="$(_catalogs_rsync_command "${catalog}"  -a --dry-run) | grep -v '\.\/' | grep -v '^directory$' | wc -l"
        eval "${cmd} > ${tmp_nfiles}"

        nfiles="$(< "${tmp_nfiles}")"
        src="$(< /tmp/_catalogs_rsync_command.src)"
        
        if (( nfiles > 0 )); then
            message_warning "Catalog ${src%/}: ${nfiles} files differ (with ${catalog_destinations[${catalog}]}/${catalog})"
        else
            message_success "Catalog ${src%/} is up-to-date (with ${catalog_destinations[${catalog}]}/${catalog})"
        fi
    done
    /bin/rm -f "${tmp_nfiles}" /tmp/_catalogs_rsync_command.src
}

function catalogs_policy() {
    cat <<- EOF

    The LAST project uses the following catalogs:
        $(echo ${!catalog_sources[@]} | fmt)

    If a LAST-CONTAINER container is available (USB disk, mounted filesystem, etc.):
     - $(ansi_underline "${PROG} check catalogs") - checks that the installed catalogs are in sync with the ones in the container
     - $(ansi_underline "${PROG} enforce catalogs") - synchronizes the catalogs with the ones in the container, installing them if needed.

    If no container is available:
     - ${PROG} check catalogs - (TBD) checks the catalogs hierarchy and checksums against values saved at installation time 

EOF
}
