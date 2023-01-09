#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include lib/wget

sections_register_section "postgres" "Maintains PostgreSQL on last0" "network"

postgres_local_hostname=$( macmap_get_local_hostname )

function postgres_psql() {
    local ask_pass
    
    ask_pass=$(mktemp)
    echo -e '#!/bin/bash\necho physics\n' > "${ask_pass}"
    chmod 700 "${ask_pass}"

    SUDO_ASKPASS=${ask_pass} sudo -A -u postgres psql -t --command "${@}" | sed -e 's;^ ;;' -e '/^$/d'
    /bin/rm "${ask_pass}"
}

function postgres_check() {

    if ! macmap_this_is_last0; then
        message_success "This machine (${postgres_local_hostname}) is not last0, nothing to do."
        return
    fi

    local ret=0

    if apt-key list 2>/dev/null | grep -q 'PostgreSQL Debian Repository' 2> /dev/null; then
        message_success 'The "PostgreSQL Debian Repository" apt-key is already installed'
    else
        message_failure 'The "PostgreSQL Debian Repository" apt-key is NOT installed'
        (( ret++ ))
    fi

    if [ -r /etc/apt/sources.list.d/pgdg.list ]; then
        message_success "The PostgreSQL apt source exists"
    else
        message_failure 'The PostgreSQL apt source does not exist'
        (( ret++ ))
    fi

    if  [ "$(dpkg --list | grep -Ec '(postgresql|postgresql-14|postgresql-client-14|postgresql-client-common|postgresql-common)')" -ge 5 ]; then
        message_success "The postgresql and postgresql-contrib packages are installed"
    else
        message_failure "Some of the postgresql and postgresql-contrib packages are missing"
        (( ret++ ))
    fi

    if [ "$(systemctl is-active postgresql)" = active ]; then
        message_success "The Postgresql service is active"
    else
        message_failure "The Postgresql service is NOT active"
        (( ret++ ))
    fi

    local conf="/etc/postgresql/14/main/postgresql.conf"
    local line
    
    if [ ! -r ${conf} ]; then
        message_failure "Missing PostgreSQL configuration file (${conf})"
    else
        line="$(grep 'listen_addresses =' ${conf} )"
        if [[ ${line} == '#listen_addresses'* ]]; then
            message_failure "The PostgreSQL server is not configured to listen to the world (${conf})"
            (( ret++ ))
        else
            message_success "The Postgresql server is configured to listen to the world (${conf})"
        fi
    fi

    conf="/etc/postgresql/14/main/pg_hba.conf"
    if [ ! -r ${conf} ]; then
        message_failure "Missing PostgreSQL configuration file (${conf})"
    else
        if grep -q 'host[[:space:]]*all[[:space:]]*all[[:space:]]*0\.0\.0\.0/0[[:space:]]*md5' ${conf}; then
            message_success "The Postgresql server has the proper connection policy (${conf})"
        else
            message_failure "The Postgresql server does NOT have the proper connection policy (${conf})"
            (( ret++ ))
        fi
    fi

    if [ "$( dpkg --list | grep -cEw '(pgadmin4|pgadmin4-server|pgadmin4-desktop)' )" -gt 3 ]; then
        message_success "The pgadmin4 packages are installed"
    else
        message_failure "The pgadmin4 packages are not installed"
        (( ret++ ))
    fi

    if ! grep -wq postgres /etc/passwd; then
        message_failure "Missing user \"postgres\"."
    else
        local line
        line="$(postgres_psql 'select version();')"
        if [[ "${line}" == PostgreSQL* ]]; then
            message_success "The Postgresql (version $(echo "${line}" | cut -d' ' -f2)) server is alive"
        else
            message_failure "The Postgresql server is NOT alive"
            (( ret++ ))
        fi
    fi

    # user 'postgres' should have a password
    local passwd
    passwd="$(postgres_psql "select passwd from pg_user where usename='postgres';")"
    if [ "${passwd}" = '********' ]; then
        message_success "The 'postgres' user already has a default password"
    else
        message_failure "The 'postgres' user does NOT have a password"
        (( ret++ ))
    fi

    # there should be a user 'ocs', with 'superuser' role
    is_super="$(postgres_psql "select usesuper from pg_user where usename='ocs';")"
    if [ ! "${is_super}" ]; then
        message_failure "Missing PostgeSQL user named 'ocs'."
        (( ret++ ))
    else
        if [ "${is_super}" = t ]; then
            message_success "PostgreSQL user 'ocs' exists and is SUPERUSER."
        else
            message_warning "PostgreSQL user 'ocs' exists but is NOT SUPERUSER."
        fi
    fi

    local conf line
    conf=/usr/pgadmin4/web/config.py
    read -r x x required <<< "$(grep MASTER_PASSWORD_REQUIRED ${conf})"
    if [ "${required,,}" = false ]; then
        message_success "Pgadmin master password is disbled (${conf})"
    else
        message_failure "Pgadmin master password is NOT disbled (${conf})"
        (( ret++ ))
    fi

    return "${ret}"
}

function postgres_enforce() {

    if ! macmap_this_is_last0; then
        message_success "This machine (${postgres_local_hostname}) is not last0, nothing to do."
        return
    fi

    if apt-key list 2>/dev/null | grep -q 'PostgreSQL Debian Repository' 2> /dev/null; then
        message_success 'The "PostgreSQL Debian Repository" apt-key already installed'
    else
        if wget ${WGET_OPTIONS} -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - >/dev/null; then
            message_success 'Added the "PostgreSQL Debian Repository" apt-key'
        else
            message_failure 'Failed to add the "PostgreSQL Debian Repository" apt-key'
            return
        fi
    fi

    if [ ! -r /etc/apt/sources.list/pgdg.list ]; then
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
        message_success 'Added the PostgreSQL apt-source list'
    fi

    if  [ "$(dpkg --list | grep -Ec '(postgresql|postgresql-14|postgresql-client-14|postgresql-client-common|postgresql-common)')" -ge 5 ]; then
        message_success "The postgresql and postgresql-contrib packages are installed"
    else
        apt update
        apt install -y postgresql postgresql-contrib
        message_success "Installed the packages postgresql and postgresql-contrib"
    fi

    local needs_restart
    needs_restart=false
    if [ "$(systemctl is-active postgresql)" = active ]; then
        message_success "The Postgresql service is active"
    else
        message_failure "The Postgresql service needs to be restarted"
        needs_restart=true
    fi

    local conf="/etc/postgresql/14/main/postgresql.conf"
    local line
    
    line="$(grep 'listen_addresses =' ${conf} )"
    if [[ ${line} == '#listen_addresses'* ]]; then
        sed -i -e "s;^#listen_addresses = 'localhost';listen_addresses = '*';" ${conf}
        message_success "Configured the Postgresql server to listen to the world (${conf})"
        needs_restart=true
    else
        message_success "The Postgresql server is already configured to listen to the world (${conf})"
    fi

    conf="/etc/postgresql/14/main/pg_hba.conf"
    if grep -q 'host[[:space:]]*all[[:space:]]*all[[:space:]]*0\.0\.0\.0/0[[:space:]]*md5' ${conf}; then
        message_success "The Postgresql server has the proper connection policy (${conf})"
    else
        echo 'host all all 0.0.0.0/0 md5' >> ${conf}
        message_success "Added the proper connection policy to the Postgresql server (${conf})"
        needs_restart=true
    fi

    if ${needs_restart}; then
        message_info "Restarting the Postgresql service"
        systemctl restart postgresql
    fi

    # pgadmin
    if apt-key list 2>/dev/null | grep -qi pgadmin; then
        message_success "The pgadmin apt key is installed"
    else
        wget ${WGET_OPTIONS} -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | apt-key add >/dev/null
        message_success 'Added the pgadmin apt-key'
    fi

    if [ -e /etc/apt/sources.list.d/pgadmin4.list ]; then
        message_success "The pgadmin apt sources list is installed"
    else
        echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list
        message_success 'Added the pgadmin apt sources list'
    fi

    if [ "$( dpkg --list | grep -cEw '(pgadmin4|pgadmin4-server|pgadmin4-desktop)' )" -gt 3 ]; then
        message_success "The pgadmin4 packages are installed"
    else
        apt update
        apt install -y pgadmin4
        message_success "Installed the pgadmin4 packages"
    fi
    # end pgadmin

    local line
    line="$(postgres_psql 'select version();')"
    if [[ "${line}" == PostgreSQL* ]]; then
        message_success "The Postgresql (version $(echo "${line}" | cut -d' ' -f2)) server is alive"
    else
        message_failure "The Postgresql server is NOT alive"
    fi

    #
    # set a default password for user 'postgres'
    # NOTE: we cannot check if this has already been done, so it is enforced every time :-(
    #
    local passwd
    passwd="$(postgres_psql "select passwd from pg_user where usename='postgres';")"
    if [ "${passwd}" = '********' ]; then
        message_success "The 'postgres' user already has a default password"
    else
        sudo -u postgres psql --command "alter user postgres password 'postgres';" >/dev/null
        message_success "Set default password for user 'postgres'"
    fi

    # there should be a user 'ocs', with 'superuser' role
    is_super="$(postgres_psql "select usesuper from pg_user where usename='ocs';")"
    if [ "${is_super}" = t ]; then
        message_success "PostgreSQL user 'ocs' exists and is SUPERUSER."
    else
        if [ "${is_super}" = f ]; then # user 'ocs' exists but is NOT superuser
            ans="$(postgres_psql "alter user ocs with superuser;")"
            if [ "${ans}" = "ALTER ROLE" ]; then
                message_success "Assigned superuser role to PostgreSQL user 'ocs'."
            else
                message_failure "Could not assign superuser role to PostgreSQL user 'ocs'."
            fi
        else    # user 'ocs' does not exist
            ans="$(postgres_psql "create user ocs;")"
            if [ "${ans}" = "CREATE USER" ]; then
                message_success "Created PostgreSQL user 'ocs'."
                ans="$(postgres_psql "alter user ocs with superuser;")"
                if [ "${ans}" = "ALTER ROLE" ]; then
                    messages_success "Assigned superuser role to PostgreSQL user 'ocs'."
                else
                    message_failure "Failed to assign superuser role to PostgreSQL user 'ocs'."
                fi
            else
                message_failure "Could not create PostgreSQL user 'ocs'."
            fi
        fi
    fi

    ans="$(postgres_psql "alter user ocs with password 'physics';")"
    if [ "${ans}" = "ALTER ROLE" ]; then
        message_success "Enforced password of PostgreSQL user 'ocs'"
    else
        message_failure "Failed to enforce password of PostgreSQL user 'ocs'"
    fi

    local conf
    conf=${user_home}/.pgpass
    if [ ! -r "${conf}" ]; then
        echo "$(macmap_get_local_ipaddr):5432:*:ocs:physics" > "${conf}"
        chmod 600 "${conf}"
        chown ocs.ocs "${conf}"
    fi

    local conf line
    conf=/usr/pgadmin4/web/config.py
    read -r x x required <<< "$(grep MASTER_PASSWORD_REQUIRED ${conf})"
    if [ "${required,,}" != false ]; then
        sed -i -e 's/MASTER_PASSWORD_REQUIRED =.*/MASTER_PASSWORD_REQUIRED = False/' "${conf}"
        message_success "Disabled pgadmin master password (${conf})"
    fi
}

function postgres_policy() {
    cat <<- EOF

    - The PostgreSQL database server and pgadmin4 should be installed (ONLY on last0)
    - The PostgreSQL server should be configured to listen to the world, and running
    
EOF
}
