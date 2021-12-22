#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "packages" "Manages additional Ubuntu packages needed by LAST" "apt"

packages_required=(
    synaptic
    mlocate
    ubuntu-software
    libusb-1.0.0-dev
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
)

function packages_run() {
    message_section "Packages"

    packages_check
    if [ ${#packages_missing[*]} -gt 0 ]; then
        message_info "Installing: ${packages_missing[*]}"
        apt install "${packages_missing[@]}"    
    fi
}

# nothing to configure here
function packages_configure() {
    :
}

function packages_check() {
    message_section "Packages"
    for package in "${packages_required[@]}"; do
        if dpkg -l "${package}" >& /dev/null; then
            message_success "Package \"${package}\" is installed"
        else
            message_warning "Package \"${package}\" is not installed"
            packages_missing+=( "${package}" )
        fi
    done
}