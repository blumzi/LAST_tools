#!/bin/bash

module_include lib/container
module_include lib/util
module_include lib/ansi

sections_register_section "last-software" "Manages our own LAST software" "user ubuntu-packages"

export fetcher last_software_github_repos_file
fetcher="$(module_locate /bin/last-fetch-from-github)"
if [[ "${-}" == *x* ]]; then
    fetcher="bash -x ${fetcher}"
fi
last_software_github_repos_file="$(module_locate files/github-repos)"

declare -a last_software_selected_repos=()
declare -g last_software_reclone=false
declare -g -x last_software_list_only=false

function last_software_helper() {
    cat <<- EOF

    Usage:
        ${PROG} enforce|check|policy last-software -l|--list
            - lists the managed LAST software repositories

        ${PROG} enforce last-software [[-r|--repo <repo>] ...] [-R|--reclone]
            - clones or pulls the specified repos (default: all repos).
            - with --reclone, discards local changes and re-clones the repository(ies) - $(ansi_bright_red DANGEROUS)

    Flags:
         -l|--list         - list the LAST software repos
         -r|--repo <repo>  - add <repo> to the selected list (default: all repos)
         -R|--reclone      - discard local changes and re-clone the (selected) repos - $(ansi_bright_red OUCH)!
         -e|--extras       - Handle the 'extras' (see below)
        -ne|--no-extras    - Do not handle the 'extras' (see below)

    Extras:
        These are packages that can be checked/enforced but are not maintained in the github repos.  They are
         delivered by the LAST-CONTAINER.
        They are:
            - the nomachine package
            - the Wine disk
            - the QHY SDK

        By default, the 'extras' are not included if any repository was specified (with --repo).

EOF
}

export last_software_extras_default=true

function last_software_arg_parser() {
    local requested_extras=false requested_no_extras=false

    while true; do
        case "${ARGV[0]}" in

        -r|--repo)
            export last_software_selected_repos+=( "${2}" )
            shiftARGV 2
            ;;

        -R|--reclone)
            export last_software_reclone=true
            shiftARGV 1
            ;;

        -l|--list)
            export last_software_list_only=true
            shiftARGV 1
            ;;

        -e|--extras)
            requested_extras=true
            shiftARGV 1
            ;;

        -ne|--no-extras)
            requested_no_extras=true
            shiftARGV 1
            ;;

        *)
            if ${requested_extras} && ${requested_no_extras}; then
                message_fatal "Cannot have both -e|--extras AND -ne|--no-extras at the same time"
            fi

            if [ ${#last_software_selected_repos[*]} -gt 0 ]; then
                if ${requested_extras}; then
                    last_software_extras=true
                fi
            else
                last_software_extras=false
            fi

            return
            ;;
        esac
    done
}

function last_software_list_repos() {
    echo ""
    printf " %-40s %-70s %s\n" "Repository" "URL" "Flags"
    printf " %-40s %-70s %s\n" "==========" "===" "====="
    while read -r repo url flags _; do
        printf " %-40s %-70s %s\n" "${repo}" "${url}" "${flags}"
    done < <(util_uncomment "$(module_locate files/github-repos)")    
}

function last_software_enforce() {
    if ${last_software_list_only}; then
        last_software_list_repos
        return
    fi
    
    message_info "Fetching the LAST software from github ..."

    local args=""
    if ${last_software_reclone}; then
        args+="--reclone "
    fi
    for repo in "${last_software_selected_repos[@]}"; do
        args+="--repo=${repo} "
    done
    # shellcheck disable=SC2154
    su "${user_last}" -c "${fetcher} ${args} --dir ~${user_last}/matlab"

    if ${last_software_extras}; then
        #
        # Frome here on we need a LAST container
        #

        if [ ! "${selected_container}" ] || [ ! -d "${selected_container}" ]; then
            message_warning "No LAST-CONTAINER.  Only the github repositories were enforced"
            return
        fi
        
        #
        # Unpack the WINE directory containing the CME2 utility
        #

        if ! macmap_this_is_last0; then
            # shellcheck disable=SC2154
            local wine_dir="${user_home}/.wine"
            local wine_tgz="${selected_container}/packages/wine+CME2.tgz"
            message_info "Unpacking the wine+CME2 repository ..."
            if [ -d "${wine_dir}" ]; then
                message_success "The directory ${wine_dir} exists"
            elif [ -r "${wine_tgz}" ]; then
                if su "${user_last}" -c "cd ~${user_last}; mkdir -p .wine; tar xzf ${wine_tgz}"; then
                    message_success "Extracted ${wine_tgz} into ${wine_dir}"
                else
                    message_failure "Could not extract ${wine_tgz} into ${wine_dir}"
                fi
            else
                message_failure "Missing ${wine_tgz}"
            fi

            util_enforce_shortcut --override --favorite CME2
        fi

        if ! macmap_this_is_last0; then
            #
            # Unpack the QFY SDK
            #
            local libdir="/usr/local/lib"
            local package="${selected_container}/packages/sdk_linux64_21.07.16.tgz"

            if [ -r "${libdir}/libqhyccd.so.21.7.16.13" ] && [ -L "${libdir}/libqhyccd.so" ] && [ -L "${libdir}/libqhyccd.so.20" ]; then
                message_success "qhy: The QHY SDK (v21.7.16.13) is installed"
            elif [ -r "${package}" ]; then
                local tmp
                tmp=$(mktemp -d)

                pushd "${tmp}" >/dev/null 2>&1 || :
                tar xzf "${package}"
                cd sdk_linux64_21.07.16 || true
                chmod +x install.sh
                ./install.sh
                popd >/dev/null 2>&1 || :
                /bin/rm -rf "${tmp}"
                message_success "Installed the QHY SDK from ${package}"
            else
                message_failure "Missing ${package}"
            fi
        fi

        #
        # Unpack NOMACINE
        #
        if ! dpkg -L nomachine >/dev/null 2>&1; then
            local deb
            deb="$( find "${selected_container}/packages" -name 'nomachine*' )"

            if [ "${deb}" ]; then
                if dpkg --install "${deb}"; then
                    message_success "Installed nomachine from \"${deb}\""
                else
                    message_failure "Could not install nomachine from \"${deb}\""
                fi
            else
                message_failure "Missing nomachine package in ${selected_container}/packages"
            fi
        else
            message_success "Nomachine is installed"
        fi
    fi
}

function last_software_check() {
    local -i ret=0
    local wine_dir="${user_home}/.wine"

    if ${last_software_list_only}; then
        last_software_list_repos
        return
    fi

    local args=""
    if ${last_software_reclone}; then
        args+="--reclone "
    fi
    for repo in "${last_software_selected_repos[@]}"; do
        args+="--repo=${repo} "
    done

    su "${user_last}" -c "${fetcher} ${args} --dir ~${user_last}/matlab --check"
    (( ret += $? ))

    if ${last_software_extras}; then
        if ! macmap_this_is_last0; then
            if [ -d "${wine_dir}" ]; then
                message_success "The directory ${wine_dir} exists"
            else
                message_failure "The ${wine_dir} directory does not exist"
                (( ret++ ))
            fi

            util_check_shortcut --favorite CME2; (( ret += ${?} ))

            local libdir="/usr/local/lib"
            if [ -r "${libdir}/libqhyccd.so.21.7.16.13" ] && [ -L "${libdir}/libqhyccd.so" ] && [ -L "${libdir}/libqhyccd.so.20" ]; then
                message_success "The QHY SDK (v21.7.16.13) is installed"
            else
                message_failure "The QHY SDK (v21.7.16.13) NOT is installed"
                (( ret++ ))
            fi
        fi

        if dpkg -L nomachine >/dev/null 2>&1; then
            message_success "Nomachine is installed"
        else
            message_failure "Nomachine is not installed"
            (( ret++ ))
        fi
    fi

    return $(( ret ))
}

function last_software_policy() { 
    cat <<- EOF

    All the LAST computers are both production AND development machines.  As such they
     contain git clones of the relevant software repositories (on github).
    
    The list of repositories is maintained in "${last_software_github_repos_file}"
    The Github tokens are maintained in "$(module_locate files/github-tokens)"

    Caveat:
        The github-tokens MUST be ignored by git (see gitignore(5))

    - $(ansi_bold "${PROG} check last-software") - checks if the local sources are up-to-date
    - $(ansi_bold "${PROG} enforce last-software") - pulls the latest sources from the repositories
    
    Software repsitories:

EOF
    su "${user_last}" -c "${fetcher} --dir ~ --list"
    echo ""

    cat <<- EOF
    The following packages cannot be installed from apt repositories, so they get installed from
     LAST packages:
     - A 'wine' repository for the "Copley Motion" windows software
     - The QHY SDK (v21.7.16.13)
     - Nomachine

EOF
}
