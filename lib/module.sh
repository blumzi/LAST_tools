#!/bin/bash

if [ ! "${MODULE_INCLUDED}" ]; then
    declare MODULE_INCLUDED=true

    declare -A module_included_modules

    function module_already_included() {
        local module="${1}"

        for m in ${!module_included_modules[*]}; do
            if [ "${m}" = "${module}" ]; then
                return 0
            fi
        done
        return 1
    }

    function module_include() {
        local module="${1}"
        local file

        if module_already_included "${module}"; then
            return
        fi

        for dir in ${LAST_MODULE_INCLUDE_PATH//:/ }; do
            file="${dir}/${module}.sh"

            if [ -r "${file}" ]; then
                # shellcheck source=/dev/null
                source "${file}"
                module_included_modules["${module}"]="${file}"
                break
            fi
        done

        #
        # If the module has an initiator, call it
        #
        # NOTE:
        #   The initiator's function name does not include the path to the module
        #   Example:
        #       module_include lib/matlab
        #     will call:
        #       matlab_init
        #
        local initiator
        initiator="$(basename "${module}")_init"
        if typeset -F "${initiator}" >/dev/null; then
            eval "${initiator}"
        fi
    }

    #
    # Lists the currently included modules
    #
    function module_list_included_modules() {
        local m

        for m in ${!module_included_modules[*]}; do
            printf "%-20s %s\n" "${m}" "${module_included_modules[${m}]}"
        done
    }

    function module_locate() {
        local name="${1}" path dir

        for dir in ${LAST_MODULE_INCLUDE_PATH//:/ }; do
            path="${dir}/${name}"
            if [ -f "${path}" ] || [ -d "${path}" ]; then
                echo "${path}"
                return
            fi
        done
    }
fi
