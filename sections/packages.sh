#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "packages" "Manages additional Ubuntu packages needed by LAST" "apt"

declare packages_missing

packages_required=(
    synaptic
    mlocate
    ubuntu-software
    libusb-dev
    xterm
    git-cola
    setserial
    matlab-support
    gnome
    unity-tweak-tool
    openssh-server
    wget
    tree
    emacs
    git
    wine
    nfs-kernel-server
    autofs
    retext

    xpa-tools
    saods9

    meld
    git
    mlocate

    telnetd
    ftpd
    xterm

    synaptic
)

function packages_enforce() {

    packages_check
    message_info "Updating apt ..."
    apt update
    if [ ${#packages_missing[*]} -gt 0 ]; then
        message_info "Installing: ${packages_missing[*]}"
        apt install -y "${packages_missing[@]}"    
    fi
}

function packages_check() {

    packages_missing=()

    if [ -x /usr/local/bin/matlab ]; then
        packages_required+=( matlab-support )   # this one needs matlab to be installed
    fi
    
    for package in "${packages_required[@]}"; do
        if dpkg -l "${package}" >& /dev/null; then
            message_success "Package \"${package}\" is installed"
        else
            message_warning "Package \"${package}\" is not installed"
            packages_missing+=( "${package}" )
        fi
    done
}

function packages_policy() {
    cat <<- EOF

    The LAST project is based ob an 'Ubuntu 20.04.03 workstation LTS' installation, with the addition 
     of the following packages:

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