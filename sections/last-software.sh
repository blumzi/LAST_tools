#!/bin/bash

module_include lib/container

sections_register_section "last-software" "Manages our own LAST software" "user ubuntu-packages"

export fetcher last_software_github_repos_file
fetcher="$(module_locate /bin/last-fetch-from-github)"
last_software_github_repos_file="$(module_locate files/github-repos)"

function last_software_enforce() {

    message_info "Fetching the LAST software from github ..."
    # shellcheck disable=SC2154
    su "${user_last}" -c "${fetcher} --dir ~${user_last}/matlab"

    #
    # Frome here on we need a LAST container
    #

    if [ ! "${selected_container}" ]; then
        message_fatal "Could not find a LAST container, please select one with --container=<path>"
    fi

    if [ ! -d "${selected_container}" ]; then
        message_fatal "The LAST container \"${selected_container}\" is not a directory."
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

        local shortcut
        shortcut="/home/${user_last}/Desktop/CME2.desktop"
        if [ -r "${shortcut}" ]; then
            message_success "The CME2 desktop shortcut exists"
        else
            cp "$(module_locate files/CME2.desktop)" "${shortcut}"
            desktop-file-install --rebuild-mime-info-cache "${shortcut}"
            message_success "Installed the CME2 desktop shortcut"
        fi
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
}

function last_software_check() {
    local -i ret=0
    local wine_dir="${user_home}/.wine"

    su "${user_last}" -c "${fetcher} --dir ~${user_last}/matlab --check"
    (( ret += $? ))

    if ! macmap_this_is_last0; then
        if [ -d "${wine_dir}" ]; then
            message_success "The directory ${wine_dir} exists"
        else
            message_failure "The ${wine_dir} directory does not exist"
            (( ret++ ))
        fi

        if [ -r /home/"${user_last}"/Desktop/CME2.desktop ]; then
            message_success "The CME2 desktop shortcut exists"
        else
            message_failure "The CME2 desktop shortcut is missing"
        fi


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

    return $(( ret ))
}

function last_software_policy() { 
    cat <<- EOF

    All the LAST computers are both production AND development machines.  As such they
     contain git clones of the relevant software repositories (on github).
    
    The list of repositories is maintained in "${last_software_github_repos_file}"
    The Github tokens are maintained in "$(module_lookup files/github-tokens)"

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
