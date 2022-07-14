#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap

sections_register_section "postgres" "Maintains PostgreSQL on last0" "network"

postgres_local_hostname=$( macmap_get_local_hostname )

function postgres_psql() {
    local ask_pass
    
    ask_pass=$(mktemp)
    echo -e '#!/bin/bash\necho physics\n' > "${ask_pass}"
    chmod 700 "${ask_pass}"

    SUDO_ASKPASS=${ask_pass} sudo -A -u postgres psql -t --command "${@}"
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
    
    line="$(grep 'listen_address =' ${conf} )"
    if [[ ${line} == '#listen_addresses'* ]]; then
        message_failure "The PostgreSQL server is not configured to listen to the world (${conf})"
        (( ret++ ))
    else
        message_success "The Postgresql server is configured to listen to the world (${conf})"
    fi

    conf="/etc/postgresql/14/main/pg_hba.conf"
    if grep -q 'host[[:space:]]*all[[:space:]]*all[[:space:]]*0\.0\.0\.0/0[[:space:]]*md5' ${conf}; then
        message_success "The Postgresql server has the proper connection policy (${conf})"
    else
        message_failure "The Postgresql server does NOT have the proper connection policy (${conf})"
        (( ret++ ))
    fi

    if [ "$( dpkg --list | grep -cEw '(pgadmin4|pgadmin4-server|pgadmin4-desktop)' )" -gt 3 ]; then
        message_success "The pgadmin4 packages are installed"
    else
        message_failure "The pgadmin4 packages are not installed"
        (( ret++ ))
    fi

    local line
    line="$(postgres_psql 'select version();')"
    if [[ "${line}" == ?PostgreSQL* ]]; then
        message_success "The Postgresql (version $(echo "${line}" | cut -d' ' -f3)) server is alive"
    else
        message_failure "The Postgresql server is NOT alive"
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
        if wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - >/dev/null; then
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
    
    line="$(grep 'listen_address =' ${conf} )"
    if [[ ${line} == '#listen_addresses'* ]]; then
        sed -i -e "s;^#listen_addresses ='localhost';listen_addresses = '*';" ${conf}
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
        wgwt --quiet -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | apt-key add >/dev/null
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
        apt install -y pgadmin4 pgadmin4-server pgadmin4-desktop
        message_success "Installed the pgadmin4 packages"
    fi
    # end pgadmin

    local line
    line="$(postgres_psql 'select version();')"
    if [[ "${line}" == ?PostgreSQL* ]]; then
        message_success "The Postgresql (version $(echo "${line}" | cut -d' ' -f3) server is alive"
    else
        message_failure "The Postgresql server is NOT alive"
    fi
}

function postgres_policy() {
    cat <<- EOF

    - The PostgreSQL database server and pgadmin4 should be installed (ONLY on last0)
    - The PostgreSQL server should be configured to listen to the world, and running
    
EOF
}
