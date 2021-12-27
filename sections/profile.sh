#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "profile" "Manages profile files"

_profile_last=/etc/profile.d/last.sh

function profile_start() {
    message_section "Profile"

    if [ ! -r "${_profile_last}" ]; then
        cat << EOF > ${_profile_last}
        #
        # Global environment for the LAST project
        #

        export http_proxy=http://bcproxy.weizmann.ac.il:8080
        export https_proxy=http://bcproxy.weizmann.ac.il:8080

        function append_to_path() {
            local subpath="\$1"
            local found=false p

            for p in \${PATH//:/ }; do
                if [ "\${p}" = "\${subpath}" ]; then
                    found=true
                    break
                fi
            done
            if ! \${found}; then
                export PATH=\${PATH}:\${subpath}
            fi
        }

        export LAST_TOOL_ROOT=/usr/local/share/last-tool
        append_to_path \${LAST_TOOL_ROOT}
        export LAST_TOOL_MATLAB_VERSION=R2020b

        export LAST_SITE_ID=0
        export LAST_SITE_NAME=weizmann
        export LAST_SITE_LAT=
        export LAST_SITE_LONG=
EOF
    fi
}

function profile_configure() {
    :
}

function profile_check() {
    message_section "Profile"
    
    if [ -r "${_profile_last}" ]; then
        message_success "The file \"${_profile_last}\" exists"
    else
        message_failure "The file \"${_profile_last}\" does not exist"
    fi
}