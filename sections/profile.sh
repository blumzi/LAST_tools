#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "profile" "Manages profile files"

_profile_last=/etc/profile.d/last.sh

function profile_enforce() {

    if [ ! -r "${_profile_last}" ]; then
        cat << EOF > ${_profile_last}
        #
        # Global environment for the LAST project
        #

        export http_proxy=http://bcproxy.weizmann.ac.il:8080
        export https_proxy=http://bcproxy.weizmann.ac.il:8080

        function append_to_module_include_path() {
            local subpath="\$1"
            local found=false p

            for p in \${LAST_MODULE_INCLUDE_PATH//:/ }; do
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
        append_to_module_include_path \${LAST_TOOL_ROOT}

        unset TMOUT
EOF
    fi
}

function profile_check() {
    
    if [ -r "${_profile_last}" ]; then
        message_success "The file \"${_profile_last}\" exists"
    else
        message_failure "The file \"${_profile_last}\" does not exist"
    fi
}