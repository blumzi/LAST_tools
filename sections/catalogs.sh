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
        [PGC]="${global_catalogs_source}"
        [data]="${user_catalogs_source}"
    )

    export -A catalog_destinations=(
        [GLADE/v1]="${global_catalogs_destination}"
        [QSO/Flesch2021]="${global_catalogs_destination}"
        [MergedCat/V2]="${global_catalogs_destination}"
        [GAIA/DR3extraGal]="${global_catalogs_destination}"
        [GAIA/DR3var]="${global_catalogs_destination}"
        [GAIA/DR3]="${global_catalogs_destination}"
        [PGC]="${global_catalogs_destination}"
        [data]="${user_catalogs_destination}"
    )
fi
export -a relevant_catalogs=( $(echo "${!catalog_sources[@]}" | tr ' ' '\n' | sort | tr '\n' ' ' ) )

longest_name=0
for c in "${!catalog_destinations[@]}"; do
    s=${catalog_destinations[${c}]}/${c}
    len=${#s}
    if (( len > longest_name )); then
        longest_name=${len}
    fi
done


function cleanup() {
	/bin/rm -rf /tmp/rsync-*${$}*
}

function catalogs_init() {
    # shellcheck disable=SC1090
    source "$(module_locate sections/network.sh)"
    network_set_defaults
}

#
# Creates an rsync command to get the list of out-of-date files
#
function _catalogs_rsync_command() {
    local added_slash=

    if [ "${1}" = "--check" ]; then
        added_slash=/
        shift 1
    fi

    local catalog="${1}"
    shift
    local -a args=( "${@}" )
    local src dst local_top

    local relevant=false c
    for c in "${relevant_catalogs[@]}"; do
        if [ "${c}" = ${catalog} ]; then
            relevant=true
            break
        fi
    done

    if ! ${relevant}; then
        message_fatal "Catalog $(ansi_bold ${catalog}) not relevant to this machine, relevant catalogs: ${relevant_catalogs[*]}"
    fi

    src=${catalog_sources[${catalog}]}/${catalog}${added_slash}
    dst=${catalog_destinations[${catalog}]}/${catalog}

    if [ -d "${src}" ]; then
        echo "rsync ${args[*]} --info=STATS0 --info=FLIST0 --itemize-changes ${src} ${dst}"
    else
        message_fatal "No source for catalog ${catalog}"
    fi
    echo "${src}" > /tmp/_catalogs_rsync_command.src
}

#
# Synchronizes a catalog
#
function catalogs_sync_catalog() {
	local catalog="${1}"
	local -i nfiles files_per_chunk=1000
    local files_list no_slashes_catalog

    # make a file containing the list of out-of-date files

    no_slashes_catalog=$( echo "${catalog}" | tr / _)
    files_list=/tmp/rsync-"${no_slashes_catalog}".${$}
    eval "$(_catalogs_rsync_command --check "${catalog}" -av --dry-run) | \
        grep -vw 'directory' | \
	    cut -d ' ' -f2 | \
        sed -e 's;[^/]*/;;' -e '/^$/d' > ${files_list}"

    # how many files are out-of-date?
    nfiles=$(wc -l < "${files_list}")

    if (( nfiles == 0 )); then
        message_success "Catalog ${catalog} is synchronized"
        return
    fi

    #
    # There are out-of-date files.
    # 1. Split the workload into chunks (default: 1000 files per chunk)
    # 2. Synchronize the chunks in parallel
    # 3. Wait for chunks to either succeed or fail
    #

    # 1. Split the workload into chunks (default: 1000 files per chunk)
	mkdir -p "${catalogs_local_top}/${catalog}"
    local dir status

    dir=${files_list}.d
    mkdir -p "${dir}"
    pushd "${dir}" >&/dev/null || true
    split --lines=${files_per_chunk} < "${files_list}"

    # 2. Synchronize the chunks in parallel
    local chunk_no=0
    local -A chunk_nos exit_status
    for chunk in x??; do
	    message_info "Synchronizing chunk #${chunk_no} of \"${catalog}\" ($(wc -l < "${chunk}") files) ..."
        eval "$(_catalogs_rsync_command ${catalog} -avq --files-from="${chunk}" ) " &
        pid=$!
        chunk_nos[${pid}]=${chunk_no}
        (( chunk_no++ ))
    done
    local nchunks=${#chunk_nos[@]}

    # 3. Wait for chunks to either succeed or fail
    local failures=0
    for pid in ${!chunk_nos[@]}; do
        wait ${pid}
        exit_status[${pid}]=$?
        if (( exit_status[${pid}] == 0 )); then
            message_success "Synchronized chunk #${chunk_nos[${pid}]} of catalog ${catalog} with ${catalog_destinations[${catalog}]}/${catalog}"
        else
            message_failure "Failed to synchronize chunk #${chunk_nos[${pid}]} of catalog ${catalog} with ${catalog_destinations[${catalog}]}/${catalog} (status: ${exit_status[${pid}]})"
            (( failures++ ))
        fi
    done

    if [ ${failures} -eq 0 ]; then
        message_success "All ${nchunks} chunk(s) of catalog ${catalog} have been successfully synchronized"
    else
        message_failure "${failures} chunk(s) (out of ${nchunks}) of catalog ${catalog} have failed"
    fi

    /bin/rm -rf "${dir}" "${files_list}"
}

function catalogs_enforce() {
    local status
    
    mkdir -p "${catalogs_local_top}"

    message_info "The following catalogs will be synchronized:"
    message_info "  $(ansi_bold ${relevant_catalogs[*]})"
    message_info ""
    for catalog in "${relevant_catalogs[@]}"; do
		catalogs_sync_catalog "${catalog}" &
    done
	wait
}

function catalogs_check() {
    local tmp_nfiles
    tmp_nfiles=$(mktemp)
    local src justified

    if [ ! -d "${catalogs_local_top}" ]; then
        message_failure "Missing \"${catalogs_local_top}\""
        return 1
    fi

    message_info "The following catalogs will be checked:"
    message_info "  $(ansi_bold ${relevant_catalogs[*]})"
    message_info ""
    for catalog in "${relevant_catalogs[@]}"; do
        local -i nfiles
        local cmd

        cmd="$(_catalogs_rsync_command --check "${catalog}"  -a --dry-run) | \
            grep -v '\.\/' | \
            grep -v '^directory$' | \
            cut -d ' ' -f2 | \
            sed -e 's;^[^/]*/;;' | \
            wc -l"
        eval "${cmd} > ${tmp_nfiles}"

        nfiles="$(< "${tmp_nfiles}")"
        src="$(< /tmp/_catalogs_rsync_command.src)"
        
        justified="$(printf "%-*s" ${longest_name} "${catalog_destinations[${catalog}]}/${catalog}")"
        if (( nfiles > 0 )); then
            message_warning "Catalog ${justified} is $(ansi_bright_red NOT) up-to-date with ${src%/}, ${nfiles} files differ"
        else
            message_success "Catalog ${justified} is up-to-date with ${src%/}"
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
