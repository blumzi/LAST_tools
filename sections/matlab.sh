#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap

export matlab_mac
export matlab_selected_release _matlab_installed_release
export -a _matlab_available_releases
export matlab_releases_dir="$(module_locate /files/matlab-releases)"

function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_available_releases() {
    echo "${_matlab_available_releases}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation" "user"

    matlab_mac=$(macmap_get_local_mac)
    
    read -r -a  _matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )
}

function matlab_enforce() {
    :
}

function matlab_configure() {
    :
}

function matlab_file_installation_keys() {
    echo "${matlab_file_installation_keys}"
}

function matlab_license_file() {
    echo "${matlab_dir}/licenses/$(mac_to_file_name "${matlab_mac}")"
}

function matlab_installed_release() {
    if which matlab >/dev/null; then
        su blumzi -c "LANG=en_US; matlab -batch 'fprintf(\"%s\",matlabRelease.Release)'" 2>/dev/null | tr -d '\n'
    fi
}

function matlab_check() {
    local -i errors ret
    local release

    message_section "Matlab"
    (( ret = 0 ))
    release=$(matlab_installed_release)
    if [ ! "${release}" ]; then
        message_failure "Matlab is not installed"
    else
        message_success "Matlab is installed (release: ${release})"
    fi

    #
    # It doesn't seem to be installed, can we install it?
    #
    if [ ! "${matlab_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return 1    # no point in continuing
    fi

    # matlab_mac="18:c0:4d:82:1d:ff"

    message_info "Checking available Matlab installations (for mac=${matlab_mac})"
    local msg keys_file license_file images_dir release_dir

    deploy_dir="$( deploy_media_dir )"
    if [ "${deploy_dir}" ] && [ -d "${deploy_dir}/matlab" ]; then
        for deployable_release in $(cd ${deploy_dir}/matlab; echo R*); do

            release_info_dir="${matlab_releases_dir}/${deployable_release}"
            (( errors = 0 ))
            msg="Release ${deployable_release}: "
            
            # check that we have the installation images for this release
            msg+=" image: ${deploy_dir}/matlab/${deployable_release}"

            keys_file="${release_info_dir}/file-installation-keys"
            msg+=", keys-file: "
            if [ -r "${keys_file}" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            # check that we have a file installation key for this machine
            msg+=", key-for-this-machine: "
            if grep -qwi "^${matlab_mac}" "${keys_file}" >/dev/null 2>&1; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            # check that we have a license key for this machine
            license_file="${release_info_dir}/licenses/$(mac_to_file_name "${matlab_mac}")"

            msg+=", license-for-this-machine: "
            if [ -r "${license_file}" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            if [ $(( errors )) -eq 0 ]; then
                message_success "${msg} (==> installable)"
            else
                (( ret++ ))
                message_failure "${msg} (==> not installable)"
            fi
        done
    fi

    return $(( ret ))
}