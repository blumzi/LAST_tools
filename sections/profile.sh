#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "profile" "Manages profile files"

_profile_last=/etc/profile.d/last.sh
_env_config_file="/etc/environment"

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
        message_success "Created \"${_profile_last}\"."
    else
        message_success "\"${_profile_last}\" already exists"
    fi

    etc_environment_enforce
}

function profile_check() {
    local errors=0

    if [ -r "${_profile_last}" ]; then
        message_success "The file \"${_profile_last}\" exists"
    else
        message_failure "The file \"${_profile_last}\" does not exist"
        (( errors++ ))
    fi

    etc_environment_check; (( errors += $? ))

    return $((errors))
}

function profile_policy() {
    cat <<- EOF

    We maintain the "${_profile_last}" file.  It allows BASH scripts to
     profit from the infrastructure developed for the LAST project (modules)

    The "${_env_config_file}" file has settings for http_proxy and https_proxy.

EOF
}

function etc_environment_check() {

    if grep -qs "^http_proxy=http://bcproxy.weizmann.ac.il:8080$" "${_env_config_file}" && 
        grep -qs "^https_proxy=http://bcproxy.weizmann.ac.il:8080$" "${_env_config_file}"; then
        message_success "The file \"${_env_config_file}\" has settings for http_proxy and https_proxy"
    else
        message_failure "The file \"${_env_config_file}\" does not have settings for http_proxy and https_proxy"
        return 1
    fi
}

function etc_environment_enforce() {
    local tmp
    tmp="$(mktemp)"

    {
        grep -vE '^(http_proxy|https_proxy)=' "${_env_config_file}"
        echo "http_proxy=http://bcproxy.weizmann.ac.il:8080"
        echo "https_proxy=http://bcproxy.weizmann.ac.il:8080"
    } > "${tmp}"
    mv "${tmp}" "${_env_config_file}"
    message_success "Added settings for http_proxy and https_proxy to \"${_env_config_file}\"."
}