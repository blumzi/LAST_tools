#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include lib/container
module_include lib/service
module_include lib/user

export matlab_local_mac
export matlab_selected_release _matlab_installed_release
export -a _matlab_available_releases
export matlab_releases_dir
matlab_releases_dir="$(module_locate files/matlab-releases)"

matlab_selected_release="R2020b"
matlab_default_release="R2020b"

# shellcheck disable=SC2154
eval user_matlab_dir="${user_home}"/matlab

# shellcheck disable=SC2154
export user_startup="${user_matlab_dir}/startup.m"
export last_startup="${user_matlab_dir}/AstroPack/matlab/startup/startup_LAST.m"


function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_available_releases() {
    echo "${_matlab_available_releases}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation" "user apt last-software"

    matlab_local_mac=$(macmap_get_local_mac)
    
    read -r -a  _matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )
}

function matlab_enforce() {
    matlab_installation_enforce
    hash -r
	matlab_startup_enforce
    astropack_startup_enforce
    matlab_support_enforce
    matlab_service_enforce
    util_enforce_shortcut --favorite matlab
}

#
# The Matlab service is responsible for running the LAST pipeline at system startup
#
function matlab_service_enforce() {
    service_enforce last-pipeline lastx
}

function matlab_license_file() {
    echo "${matlab_releases_dir}/${matlab_selected_release}/licenses/$(mac_to_file_name "${matlab_local_mac}")"
}

function matlab_installed_release() {
    local status str

    which matlab >& /dev/null
    status=${?}
    if (( status == 0 )); then
        str="$( stat --format '%N' "$(which matlab)" | tr -d "'" | (read -r _ _ file; echo "${file}" ) )"
        str="${str%/bin/matlab}"
        str="${str/*\/R/R}"
        echo "${str}"
    fi
}

function matlab_check() {
    local -i ret=0

    if [ "${matlab_list_releases_only}" = true ]; then
        matlab_installation_check;          (( ret += $? ))
        return $(( ret ))
    fi
    
    matlab_installation_check;              (( ret += $? ))
    matlab_startup_check;                   (( ret += $? ))
    astropack_startup_check;                (( ret += $? ))
    matlab_support_check;                   (( ret += $? ))
    matlab_service_check;                   (( ret += $? ))
    util_check_shortcut --favorite matlab;  (( ret += $? ))

    return $(( ret ))
}

function matlab_service_check() {
    service_check last-pipeline lastx
}

#
# At this point-in-time we assume there's only ONE installation image on LAST-CONTAINER
# TBD: how to choose between more than one
#
function matlab_installation_enforce() {
    local installed_release
    installed_release=$(matlab_installed_release)

    if [ "${installed_release}" = "${matlab_selected_release}" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
        return
    fi

    local installer_input activate_ini
    local keys_file local_mac container installer config_file

    local matlab_top
    matlab_top="/usr/local/MATLAB/${matlab_selected_release}"
	export MATLABROOT=${matlab_top}

    if [ -d "${matlab_top}" ] && [ -x "${MATLABROOT}/bin/matlab" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
    else
        local_mac=$( macmap_get_local_mac )

        container=${selected_container}
        installer=${container}/matlab/${matlab_selected_release}/install
        if [ ! -x "${installer}" ]; then
            message_fatal "Missing installer for Matlab ${matlab_selected_release} in ${installer}, exiting"
        fi

        keys_file="${matlab_releases_dir}/${matlab_selected_release}/file-installation-keys"

        if [ ! -r "${keys_file}" ]; then
            message_fatal "Cannot read keys file \"${keys_file}\", exiting"
        fi

        local installation_key
        read -r installation_key <<< "$(util_uncomment "${keys_file}" )"
        if [ ! "${installation_key}" ]; then
            message_fatal "Cannot get installation key for release=${matlab_selected_release} from \"${keys_file}\", exiting"
        fi

        # Access the matlab installer

        mkdir -p "${matlab_top}"
        #
        # Prepare responses for the silent Matlab installation
        #
        installer_input=$( mktemp ) 
        cat <<- EOF > "${installer_input}"

        ## SPECIFY INSTALLATION FOLDER
        destinationFolder=${matlab_top}

        ## SPECIFY FILE INSTALLATION KEY
        fileInstallationKey=${installation_key}

        ## ACCEPT LICENSE AGREEMENT 
        agreeToLicense=yes

        ## SPECIFY OUTPUT LOG
        outputFile=/tmp/matlab${matlab_selected_release}-install.log

        ## SPECIFY INSTALLER MODE
        mode=silent
EOF
        local -i status
        pushd "$(dirname "${installer}")" >/dev/null || true
        message_info "Silently installing Matlab ${matlab_selected_release} from \"$(dirname "${installer}")\" (~10 minutes, get some coffee :)"
        ./install -inputFile "${installer_input}"
        status=${?}
        if [ ${status} -eq 0 ]; then
            message_success "Installed Matlab ${matlab_selected_release}"
        else
            message_fatal "Failed to install Matlab ${matlab_selected_release} (status=${status})"
        fi

        # Then we will need to replce lmgrimpl module in the matlab installation directory for activation
        sudo cp -r ${matlab_top}/bin/* ${MATLABROOT}/bin 2>/dev/null
		/bin/rm -f "${installer_input}"
    fi

    hash >&/dev/null # to hash the newly installed Matlab

	local matlabroot existent_license_file
    matlabroot=/usr/local/MATLAB/${matlab_selected_release}
	existent_license_file="$( find "${matlabroot}"/licenses -name "license_$(hostname -s)_*_${matlab_selected_release}.lic" )"

	if [ ! "${existent_license_file}" ]; then

		#
		# Prepare activation responses for the Matlab installation
		#
		activate_ini=$( mktemp )
		cat <<- EOF > "${activate_ini}"
		# SPECIFY ACTIVATION MODE
		isSilent=true
		# SPECIFY ACTIVATION TYPE (Required)
		activateCommand=activateOffline
		# SPECIFY LICENSE FILE LOCATION (Required if activateCommand=activateOffline)
		licenseFile=$(matlab_license_file)
	EOF
		message_info "Silently activating Matlab ${matlab_selected_release} (~1 minute) ..."
		# Activate the Matlab by running, it will says 'success'
		declare result
		result="$( ${matlab_top}/bin/activate_matlab.sh -propertiesFile "${activate_ini}" )"
		status=${?}
		if [ ${status} -eq 0 ] && [ "${result}" = "Silent activation succeeded." ]; then
			message_success "Successfuly activated Matlab ${matlab_selected_release}"
		else
			message_fatal "Failed to activate Matlab ${matlab_selected_release} (status=${status})"
		fi
	else
		message_success "Matlab ${matlab_selected_release} has already been activated"
	fi

    # Finally, link the matlab to /usr/local/bin, 
    ln -sf ${matlab_top}/bin/matlab /usr/local/bin/matlab-${matlab_selected_release}

    local tmp
    tmp=$( mktemp )
    # shellcheck disable=SC2154
    bashrc="${user_home}/.bashrc"
    {
        grep -v "MATLABROOT" "${bashrc}"
        echo "export MATLABROOT=${matlab_top}/bin"
        echo "export PATH=\${PATH}:MATLABROOT/bin"
    } > "${tmp}"
    mv "${tmp}" "${bashrc}"
    chown "${user_name}"."${user_group}" "${bashrc}"
    message_success "Added MATLABROOT=${matlab_top}/bin to ${bashrc}"

    /bin/rm "${activate_ini}" >& /dev/null

    config_file="/etc/matlab/debconf"
    if [ ! -r "${config_file}" ]; then
        local our_config_file

        our_config_file=$(module_locate files/root/${config_file})
        if [ -r "${our_config_file}" ]; then
            install -D "${our_config_file}" "${config_file}"
            message_success "Installed \"${config_file}\"."
        else
            message_failure "Missing \".../files/root/${config_file}\"."
        fi
    else
        message_success "File \"${config_file}\" exists"
    fi

    export MATLABROOT=${matlab_top}/bin
    # if ! dpkg -l matlab-support >&/dev/null; then
    #     message_info "Installing matlab-support"
    #     apt -y install matlab-support
    # fi
}

function matlab_installation_check() {
    local release container
    local -i ret=0 errors=0

    release=$(matlab_installed_release)
    if [ ! "${release}" ]; then
        message_failure "Matlab is not installed"
        (( errors++ ))
    else
        message_success "Matlab is installed (release: ${release})"
    fi

    #
    # It doesn't seem to be installed, can we install it?
    #
    if [ ! "${matlab_local_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return $(( ++errors ))    # no point in continuing
    fi

    if [ "${selected_container}" ]; then
        message_info "Checking available Matlab installations (for mac=${matlab_local_mac})"
        local msg keys_file license_file
        container="${selected_container}"
        for deployable_release in $(cd "${container}/matlab" || exit; echo R*); do

            release_info_dir="${matlab_releases_dir}/${deployable_release}"
            (( errors = 0 ))
            if [ "${deployable_release}" = "${matlab_selected_release}" ]; then
                msg="Release $(ansi_bright_green "${deployable_release}"): "
            else
                msg="Release ${deployable_release}"
            fi
            
            # check that we have the installation images for this release
            msg+=", installer "
            if [ -x "${container}/matlab/${deployable_release}/install" ]; then
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
            msg+=", file-installation-keys: "
            if [ -r "${keys_file}" ]; then
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

            if (( errors == 0 )); then
                message_success "${msg} (==> installable)"
            else
                (( ret++ ))
                message_failure "${msg} (==> not installable)"
            fi
        done
    else
        message_info "No selected container, cannot check Matlab installation availability"
    fi

    return $(( ret ))
}

function matlab_policy() {
    cat <<- EOF

    The LAST project currently uses Matlab ${matlab_selected_release}.

    - $(ansi_underline "${PROG} check matlab") - Checks that the relevant Matlab release is properly installed.
    - $(ansi_underline "${PROG} enforce matlab") - Installs the relevant Matlab release from a LAST-CONTAINER.

    If Matlab is installed, some of the libraries it fetches must be moved aside.

    The file ${last_startup} should be hard linked to ${user_startup}.

EOF
}

function matlab_is_installed() {
    command -v matlab >&/dev/null
}

#
# Startup
#
function matlab_startup_check() {
    declare -i errors=0

    if macmap_this_is_last0; then
        message_success "No startups on last0"
        return 0
    fi

    if [ ! -r "${last_startup}" ]; then
        message_failure "Missing \"${last_startup}\""
        (( errors++ ))
	else
		message_success "LAST startup \"${last_startup}\" exists"
    fi

    if [ ! -r "${user_startup}" ]; then
        message_failure "Missing \"${user_startup}\""
        (( errors++ ))
	else
		message_success "User startup \"${user_startup}\" exists"
    fi

	if [ -r "${user_startup}" ] && [ -r "${last_startup}" ]; then
		local inode0 inode1
		inode0="$(stat --format "%i" "${user_startup}" 2>/dev/null)"
		inode1="$(stat --format "%i" "${last_startup}" 2>/dev/null)"
		if [ "${inode0}" != "${inode1}" ]; then
			message_failure "\"${user_startup}\" is not hard linked to \"${last_startup}\""
			(( errors++ ))
		else
			message_success "\"${user_startup}\" is hard linked to \"${last_startup}\""
		fi
	fi

    return $(( errors ))
}

function matlab_startup_enforce() {
    declare -i errors=0

    if macmap_this_is_last0; then
        message_success "No startup on last0"
        return 0
    fi

    if [ ! -r "${last_startup}" ]; then
        message_failure "Missing \"${last_startup}\""
        (( errors++ ))
    fi

    ln -f "${last_startup}" "${user_startup}"
    message_success "Linked \"${last_startup}\" to \"${user_startup}\"."

    return $(( errors ))
}

#
# The "matlab-support" package doesn't want to be installed non-ineractively.
# We emulate its behavior, without actually installing it.
#

#
# This function was plagiated from the matlab-support's postinst script
#
function matlab_support_enforce() {
    local matlab_alt matlab_alts matlab_path mpath
    local op="matlab-support"

    mpath=/usr/local/MATLAB/R2020b
    update-alternatives --install \
        /usr/bin/matlab matlab $mpath/bin/matlab -1 \
        --slave /usr/bin/matlab-mex matlab-mex $mpath/bin/mex  \
        --slave /usr/bin/matlab-mbuild matlab-mbuild $mpath/bin/mbuild
    message_success "${op}: Installed the matlab alternatives"

    matlab_alts="$(update-alternatives --query matlab 2>/dev/null | grep 'Alternative:' | cut -d ' ' -f 2,2)"
    if [ "${matlab_alts}" ]; then
        for matlab_alt in ${matlab_alts}
        do
            matlab_path=${matlab_alt%*/bin/matlab}
            # The SONAMEs listed here should be kept in sync with the
            # “Recommends” field of matlab-support binary package
                        # $matlab_path/sys/os/glnxa64/libgfortran.so.5
            for f in $matlab_path/sys/os/glnx86/libgcc_s.so.1 \
                        $matlab_path/sys/os/glnx86/libstdc++.so.6 \
                        $matlab_path/sys/os/glnx86/libgfortran.so.5 \
                        $matlab_path/sys/os/glnx86/libquadmath.so.0 \
                        $matlab_path/sys/os/glnxa64/libgcc_s.so.1 \
                        $matlab_path/sys/os/glnxa64/libstdc++.so.6 \
                        $matlab_path/sys/os/glnxa64/libquadmath.so.0
            do
                if [ -e "${f}" ]; then
                    if mv "${f}" "${f}.bak"; then
                        message_success "${op}: Moved ${f} to ${f}.bak"
                    else
                        message_failure "${op}: Failed to move ${f} to ${f}.bak"
                    fi
                fi
            done
        done
    else
        message_warning "${op}: The matlab alternative links were not created"
    fi
}

function matlab_support_check() {
    local matlab_alt matlab_alts matlab_path
    local op="matlab-support"
    local -i errors=0

    matlab_alts="$(update-alternatives --query matlab 2>/dev/null | grep 'Alternative:' | cut -d ' ' -f 2,2)"
    if [ "${matlab_alts}" ]; then
        for matlab_alt in ${matlab_alts}
        do
            matlab_path=${matlab_alt%*/bin/matlab}
            # The SONAMEs listed here should be kept in sync with the
            # “Recommends” field of matlab-support binary package
                #  $matlab_path/sys/os/glnx86/libgfortran.so.5
                # $matlab_path/sys/os/glnxa64/libgfortran.so.5
            for f in $matlab_path/sys/os/glnx86/libgcc_s.so.1 \
                        $matlab_path/sys/os/glnx86/libstdc++.so.6 \
                        $matlab_path/sys/os/glnx86/libquadmath.so.0 \
                        $matlab_path/sys/os/glnxa64/libgcc_s.so.1 \
                        $matlab_path/sys/os/glnxa64/libstdc++.so.6 \
                        $matlab_path/sys/os/glnxa64/libquadmath.so.0
            do
                if [ -e "${f}" ]; then
                    message_failure "${op}: ${f} still exists"
                    (( errors++ ))
                elif [ -e "${f}.bak" ]; then
                    message_success "${op}: ${f} was moved aside"
                fi
            done
        done
    else
        message_warning "${op}: The matlab alternative links were not created"
    fi
    return $(( errors ))
}


#
# AstroPack
#

function astropack_startup_check() {
    local msg
    local -i ret=0

    if macmap_this_is_last0; then
        message_success "No startup checks on last0"
        return 0
    fi

    msg="The script startup_Installer in \"${user_matlab_dir}/AstroPack/matlab/startup\" was"
    if [ -d "${user_matlab_dir}/data" ]; then
        message_success "${msg} invoked"
    else
        message_failure "${msg} NOT invoked"
        (( ret++ ))
    fi
    return $(( ret ))
}

function astropack_startup_enforce() {
    local script
    script="startup_Installer"

    if macmap_this_is_last0; then
        message_success "No startup scripts on last0 (yet?)"
        return
    fi

    # shellcheck disable=SC2154
    if [ -d "${user_matlab_dir}/data" ]; then
        message_success "The script ${script} was invoked"
    else
        message_info "Invoking \"${script}\" in \"AstroPack/matlab/startup\" ..."
        su "${user_name}" -c "cd ~/matlab; LANG=en_US matlab -batch \"addpath('/home/ocs/matlab/AstroPack/matlab/startup'); ${script}\" "
        status=${?}
        if (( status == 0 )); then
            message_success "${script} has succeeded"
        else
            message_failure "${script} has failed with status: ${status}"
        fi
    fi
}

function matlab_arg_parser() {
    local requested_release

    while true; do
        case "${ARGV[0]}" in

        -r|--release)
            requested_release+=( "${2}" )
            shiftARGV 2
            ;;

        -l|--list-releases)
            export matlab_list_releases_only=true
            shiftARGV 1
            ;;

        *)
            if [ "${requested_release}" ]; then
                matlab_selected_release="${requested_release}"
            else
                matlab_selected_release="${matlab_default_release}"
            fi
            return
            ;;
        esac
    done
}

function matlab_helper() {
    cat <<- EOF

    Usage:
        ${PROG} check matlab [-l|--list-releases] [-r|--release <release>]
            - lists the matlab releases available in the LAST-CONTAINER

        ${PROG} enforce matlab [-r|--release <release>]
            - installs the specified matlab release (default: ${matlab_default_release})

    Flags:
         -l|--list-release      - list the matlab releases available for installation
         -r|--release <release> - specifies the matlab release to work with (default: ${matlab_default_release})

EOF
}
