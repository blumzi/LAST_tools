#!/bin/bash

module_include lib/container

sections_register_section "software" "Manages our own LAST software" "user"

export fetcher="${LAST_TOOL_ROOT}/bin/last-fetch-from-github"

function software_enforce() {

    message_info "Fetching the LAST software from github ..."
    su "${user_last}" -c "${fetcher} --dir /home/${user_last}"

    local wine_dir="/home/${user_last}/.wine"
    local wine_tgz="${selected_container}/packages/wine+CME2.tgz"
    message_info "Unpacking the wine+CME2 repository ..."
    if [ ! -d "${wine_dir}" ]; then
        message_success "The directory ${wine_dir} exists"
    elif [ -r "${wine_tgz}" ]; then
        su "${user_last}" -c "cd /home/${user_last}; tar xzf ${wine_tgz}"
        message_success "Extracted ${wine_tgz} into ${wine_dir}"
    else
        message_failure "Missing ${wine_tgz}"
    fi

    local libdir="/usr/local/lib"
    local package="${selected_container}/packages/sdk_linux64_21.07.16.tgz"

    if [ -r "${libdir}/libqhyccd.so.21.7.16.13" ] && [ -L "${libdir}/libqhyccd.so" ] && [ -L "${libdir}/libqhyccd.so.20" ]; then
        message_success "qhy: The QHY SDK (v21.7.16.13) is installed"
    elif [ -r "${package}" ]; then
        local tmp
        tmp=$(mktemp -d)

        pushd "${tmp}" >/dev/null 2>&1 || :
        tar xzf "${package}"
        chmod +x install.sh
        ./install.sh
        popd >/dev/null 2>&1 || :
        /bin/rm -rf "${tmp}"
        message_success "Installed the QHY SDK from ${package}"
    else
        message_failure "Missing ${package}"
    fi
}

function software_check() {
    local -i ret=0
    local wine_dir="/home/${user_last}/.wine"

    su "${user_last}" -c "${fetcher} --dir /home/${user_last} --check --token ${github_token}"
    (( ret += $? ))

    if [ -d "${wine_dir}" ]; then
        message_success "wine: The directory ${wine_dir} exists"
    else
        message_failure "wine: The ${wine_dir} directory does not exist"
        (( ret++ ))
    fi

    local libdir="/usr/local/lib"
    if [ -r "${libdir}/libqhyccd.so.21.7.16.13" ] && [ -L "${libdir}/libqhyccd.so" ] && [ -L "${libdir}/libqhyccd.so.20" ]; then
        message_success "qhy: The QHY SDK (v21.7.16.13) is installed"
    else
        message_failure "qhy: The QHY SDK (v21.7.16.13) NOT is installed"
        (( ret++ ))
    fi

    return $(( ret ))
}

function software_policy() { 
    cat <<- EOF

    All the LAST computers are both production AND development machines.  As such they
     contain git clones of the relevant software repositories (on github). You

    - $(ansi_underline "${PROG} check software") - checks if the local sources are up-to-date
    - $(ansi_underline "${PROG} enforce software") - pulls the latest sources from the repositories
    
    Software repsitories:

EOF
    su "${user_last}" -c "${fetcher} --dir ~ --list"
    echo ""

    cat <<- EOF
    The following packages are also enforced or checked:
     - A 'wine' repository for the "Copley Motion" windows software
     - The QHY SDK (v21.7.16.13)

EOF
}
