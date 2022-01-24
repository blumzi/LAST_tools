#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/util

sections_register_section "ubuntu-packages" "Manages additional Ubuntu packages needed by LAST" "apt"

export -a ubuntu_packages_missing
export ubuntu_packages_file="$(module_locate files/ubuntu-packages)"

# get the list of additional packages required from a file, ignoring comments and empty lines
mapfile -t ubuntu_packages_missing < <( util_uncomment "${ubuntu_packages_file}" )

if [ -x /usr/local/bin/matlab ]; then
    ubuntu_packages_missing+=( matlab-support )   # this one needs matlab to be installed
fi

function ubuntu_packages_enforce() {

    LAST_TOOL_QUIET=true packages_check
    message_info "Updating apt ..."
    apt -qq --no-show-upgraded update
    if [ ${#ubuntu_packages_missing[*]} -gt 0 ]; then
        message_info "Installing: ${ubuntu_packages_missing[*]}"
        apt install -qq -y "${ubuntu_packages_missing[@]}"    
    fi
}

function ubuntu_packages_check() {
    local package

    for package in "${ubuntu_packages_missing[@]}"; do
        if dpkg -L "${package}" >& /dev/null; then
            message_success "Package \"${package}\" is installed"
        else
            message_warning "Package \"${package}\" is not installed"
            ubuntu_packages_missing+=( "${package}" )
        fi
    done
}

function ubuntu_packages_policy() {
    cat <<- EOF

    The LAST project is based on an 'Ubuntu 20.04.03 workstation LTS' installation.
    A list of additional packages is maintained in "${ubuntu_packages_file}".

    The list of currently added packages is:

EOF
    local package
    for package in "${ubuntu_packages_missing[@]}"; do
        echo "${package}"
    done | fmt -w 70 | sed -e 's;^;    ;'

    cat <<- EOF

    - $(ansi_underline "${PROG} check packages") - checks if the required packages are installed
    - $(ansi_underline "${PROG} enforce packages") - attempts to install the packages (and dependencies)

EOF
}
