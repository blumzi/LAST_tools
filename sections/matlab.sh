#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap

export matlab_local_mac
export matlab_selected_release _matlab_installed_release
export -a _matlab_available_releases
export matlab_releases_dir
matlab_releases_dir="$(module_locate files/matlab-releases)"

matlab_selected_release="R2020b"

function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_available_releases() {
    echo "${_matlab_available_releases}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation" "user"

    matlab_local_mac=$(macmap_get_local_mac)
    
    read -r -a  _matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )
}

function matlab_enforce() {
    local installed_release
    installed_release=$(matlab_installed_release)

    if [ "${installed_release}" = "${matlab_selected_release}" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
        return
    fi

    matlab_install
}

function matlab_license_file() {
    echo "${matlab_releases_dir}/licenses/$(mac_to_file_name "${matlab_local_mac}")"
}

function matlab_installed_release() {
    if which matlab >/dev/null; then
        su "${user_last}" -c "LANG=en_US; matlab -batch 'fprintf(\"%s\",matlabRelease.Release)'" 2>/dev/null | tr -d '\n'
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
    if [ ! "${matlab_local_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return 1    # no point in continuing
    fi

    # matlab_local_mac="18:c0:4d:82:1d:ff"

    message_info "Checking available Matlab installations (for mac=${matlab_local_mac})"
    local msg keys_file license_file

    deploy_dir="$( deploy_container )"
    if [ "${deploy_dir}" ] && [ -d "${deploy_dir}/matlab" ]; then
        for deployable_release in $(cd "${deploy_dir}/matlab" || exit; echo R*); do

            release_info_dir="${matlab_releases_dir}/${deployable_release}"
            (( errors = 0 ))
            if [ "${deployable_release}" = "${matlab_selected_release}" ]; then
                msg="Release $(ansi_bright_green "${deployable_release}"): "
            else
                msg="Release ${deployable_release}"
            fi
            
            iso=$(cd "${deploy_dir}/matlab/${deployable_release}" || exit ; echo *.iso)
            # check that we have the installation images for this release
            msg+=", installer "
            if [ -x "${deploy_dir}/matlab/${deployable_release}/install" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

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
            if grep -qwi "^${matlab_local_mac}" "${keys_file}" >/dev/null 2>&1; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            # check that we have a license key for this machine
            license_file="${release_info_dir}/licenses/$(mac_to_file_name "${matlab_local_mac}")"

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

#
# At this point-in-time we assume there's only ONE installation image on LAST-DEPLOYER
# TBD: how to choose between more than one
#
function matlab_install() {
    local installer_input activate_ini
    local keys_file local_mac container installer

    local_mac=$( macmap_get_local_mac )

    container=$( deploy_container )
    installer=${container}/matlab/${matlab_selected_release}/install
    if [ ! -x "${installer}" ]; then
        message_fatal "Missing installer for Matlab ${matlab_selected_release} in ${installer}, exiting"
    fi

    keys_file="${matlab_releases_dir}/${matlab_selected_release}/file-installation-keys"

    if [ ! -r "${keys_file}" ]; then
        message_fatal "Cannot read keys file \"${keys_file}\", exiting"
    fi

    local -a keys_info
    read -r -a keys_info <<< <(grep -i "^${local_mac}")
    if [ ${#keys_info[*]} -ne 2 ]; then
        message_fatal "Cannot get installation key for mac=${local_mac} from \"${keys_file}\", exiting"
    fi

    local installation_key
    installation_key="${keys_info[1]}"

    # Access the matlab installer

    # Access the .iso file
    local matlab_top
    matlab_top="/usr/local/MATLAB/${matlab_selected_release}"

    mkdir -p "${matlab_top}"
    #
    # Prepare responses for the silent Matlab installation
    #
    installer_input=$( mktemp ) 
    cat << EOF > "${installer_input}"

    ## SPECIFY INSTALLATION FOLDER
    destinationFolder=${matlab_top}

    ## SPECIFY FILE INSTALLATION KEY
    leInstallationKey=${installation_key}

    ## ACCEPT LICENSE AGREEMENT 
    agreeToLicense=yes

    ## SPECIFY OUTPUT LOG
    outputFile=/tmp/matlab${matlab_selected_release}-install.log

    ## SPECIFY INSTALLER MODE
    mode=silent
EOF

    #
    # Prepare activation responses for the Matlab installation
    #
    activate_ini=$( mktemp )
    cat << EOF > "${activate_ini}"
    # SPECIFY ACTIVATION MODE
    isSilent=true
    # SPECIFY ACTIVATION TYPE (Required)
    activateCommand=activateOffline
    # SPECIFY LICENSE FILE LOCATION (Required if activateCommand=activateOffline)
    licenseFile=$(matlab_license_file)
EOF

    pushd "$(dirname "${installer}")" >/dev/null || return
    ./install -inputFile "${installer_input}"
    local -i status=${?}
    if [ ${status} -eq 0 ]; then
        message_success "Installed Matlab ${matlab_selected_release}"
    else
        message_fatal "Failed to install Matlab ${matlab_selected_release} (status=${status})"
    fi

    export MATLABROOT=${matlab_top}/bin

    # Then we will need to replce lmgrimpl module in the matlab installation directory for activation
    sudo cp ${matlab_top}/bin/* ${MATLABROOT}

    # Activate the Matlab by running, it will says 'success'
    ${matlab_top}/bin/activate_matlab.sh -propertiesFile activate.ini
    status=${?}
    if [ ${status} -eq 0 ]; then
        message_success "Activated Matlab ${matlab_selected_release}"
    else
        message_fatal "Failed to activate Matlab ${matlab_selected_release} (status=${status})"
    fi

    # Finally, link the matlab to /usr/local/bin, 
    ln -sf ${matlab_top}/bin/matlab /usr/local/bin/matlab

    local tmp
    tmp=$( mktemp )
    bashrc=/home/${user_last}/.bashrc
    {
        grep -v "export MATLABROOT=" "${bashrc}"
        echo "export MATLABROOT=${matlab_top}/bin"
    } > "${tmp}"
    mv "${tmp}" "${bashrc}"
    message_success "Added MATLABROOT=${matlab_top}/bin to ${bashrc}"

    /bin/rm "${installer_input}" "${activate_ini}"
}
