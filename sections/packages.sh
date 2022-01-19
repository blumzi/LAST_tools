#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/util

sections_register_section "packages" "Manages additional Ubuntu packages needed by LAST" "apt"

declare packages_missing
declare additional_packages_file="${LAST_TOOL_ROOT}/files/additional-packages"

# get the list of additional packages required from a file, ignoring comments and empty lines
mapfile -t packages_required < <( util_uncomment "${additional_packages_file}" )

if [ -x /usr/local/bin/matlab ]; then
    packages_required+=( matlab-support )   # this one needs matlab to be installed
fi

function packages_enforce() {

    LAST_TOOL_QUIET=true packages_check
    message_info "Updating apt ..."
    apt -qq --no-show-upgraded update
    if [ ${#packages_missing[*]} -gt 0 ]; then
        message_info "Installing: ${packages_missing[*]}"
        apt install -qq -y "${packages_missing[@]}"    
    fi
}

function packages_check() {

    packages_missing=()
    
    for package in "${packages_required[@]}"; do
        if dpkg -L "${package}" >& /dev/null; then
            message_success "Package \"${package}\" is installed"
        else
            message_warning "Package \"${package}\" is not installed"
            packages_missing+=( "${package}" )
        fi
    done
}

function packages_policy() {
    cat <<- EOF

    The LAST project is based on an 'Ubuntu 20.04.03 workstation LTS' installation.
    A list of additional packages is maintained in ${additional_packages_file}.

    The list of currently added packages is:

EOF
    local package
    for package in "${packages_required[@]}"; do
        echo "${package}"
    done | fmt -w 50 | sed -e 's;^;    ;'

    cat <<- EOF

    - $(ansi_underline "${PROG} check packages") - checks if the required packages are installed
    - $(ansi_underline "${PROG} enforce packages") - attempts to install the packages (and dependencies)

EOF
}
