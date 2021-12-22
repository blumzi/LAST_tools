#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "profile" "Manages profile files"

_profile_last=/etc/profile.d/last.sh

function profile_run() {
    message_section "Profile"

    if [ ! -r "${_profile_last}" ]; then
        cat << EOF > ${_profile_last}
        #
        # Global environment for the LAST project
        #

        export http_proxy=http://bcproxy.weizmann.ac.il:8080
        export https_proxy=http://bcproxy.weizmann.ac.il:8080

        export LAST_ROOT=/usr/local/share/last-tools
        found=false
        for p in \${PATH//:/ }; do
            if [ "\${p}" = "\${LAST_ROOT}" ]; then
                found=true
                break
            fi
        done
        if ! \${found}; then
            export PATH=\${PATH}:\${LAST_ROOT}
        fi
        unset found p
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