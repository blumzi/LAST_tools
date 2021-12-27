#!/bin/bash

if [ ! "${MODULE_INCLUDED}" ]; then
    export MODULE_INCLUDED=true

    declare -a module_included

    function module_already_included() {
        local module="${1}"

        for m in "${module_included[@]}"; do
            if [ "${m}" = "${module}" ]; then
                return 0
            fi
        done
        return 1
    }

    function module_include() {
        local module="${1}"

        if ! module_already_included "${module}"; then
            if ! eval source "${module}.sh" 2>/dev/null; then
                message_failure "module_include: Cannot include module \"${module}\" (source ${module}.sh failed)."
                exit 1
            fi
            module_included+=( "${module}" )

            # if the module has an initiator, call it
            local initiator
            initiator="$(basename "${module}")_init"
            if typeset -F "${initiator}" >/dev/null; then
                eval "${initiator}"
            fi
        fi
    }

    function module_list_included() {
        echo "${module_included[@]}"
    }
fi