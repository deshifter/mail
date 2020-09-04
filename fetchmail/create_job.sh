#!/usr/bin/env bash

set -e

function unlock_and_exit() {
    rm -f /tmp/mail/fetchmail_create_job.lock && exit
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    unlock_and_exit
fi

if [ ! -d "/tmp/mail" ]; then
    mkdir -p /tmp/mail
elif [ ! -e "/tmp/mail/fetchmail_create_job.lock" ]; then
    touch /tmp/mail/fetchmail_create_job.lock
else
    echo "Process if locked"
    exit
fi

# maildir path
maildir_path="/home/mail"

if [ ! -d "${maildir_path}" ]; then
    echo "Can\'t open ${maildir_path}: Directory nonexistent"
    unlock_and_exit
fi

# log links path
log_links_path="/var/log"

# local mail server
my_domain=$(hostname -d)

# external mail server
ext_hostname="mail.termoxid.com"
ext_use_ssl=no
ext_port=143
ext_proto="imap"
ext_user=
ext_password=

# keep messages on external server
keep_on_server=no
# max count mails for one connection
fetch_limit_count=5

# overwrite existed config files
force_overwrite=false

while [ -n "$1" ]; do
    case "$1" in
    -F | --force)
        force_overwrite=true
        echo "force_overwrite=true"
        shift
        ;;
    -f | --from)
        ext_user="$2"
        echo "ext_user=\"$2\""
        shift
        ;;
    -p | --password)
        ext_password="$2"
        echo "ext_password=\"$2\""
        shift
        ;;
    -t | --to)
        local_username="$2"
        echo "local_username\"$2\""
        shift
        ;;
    *) ;;
    esac
    shift
done

if [ -z "${ext_user}" ] || [ -z "${ext_password}" ] || [ -z "${local_username}" ]; then
    echo "Too few arguments. Use: ./install.sh -f USER -p PASSWORD -t USERNAME"
    unlock_and_exit
fi

mailbox_path="${maildir_path}/${my_domain}/${local_username}@${my_domain}"

if [ ! -d "${mailbox_path}" ]; then
    echo "cannot open ${mailbox_path}: Directory nonexistent"
    unlock_and_exit
fi

if [ $ext_use_ssl = yes ] || [ $ext_use_ssl = true ]; then
    ssl_config="ssl"
fi

if [ $ext_use_ssl = no ] || [ $ext_use_ssl = false ]; then
    ssl_config="sslproto ''"
fi

if [ $keep_on_server = yes ] || [ $keep_on_server = true ]; then
    keep="keep"
fi

if [ $keep_on_server = no ] || [ $keep_on_server = false ]; then
    keep="no keep"
fi

procmail_maildir_path="${mailbox_path}"
procmail_default_path="${mailbox_path}"

fetchmail_conf_path="${mailbox_path}/fetchmail-${ext_user}.conf" #TODO ext_email
procmail_conf_path="${mailbox_path}/procmail-${ext_user}.conf"

procmail_log_path="${mailbox_path}/procmail.log"
fetchmail_log_path="${mailbox_path}/fetchmail.log"

########################################
########### fetchmail config ###########
########################################

if [ -e "${fetchmail_conf_path}" ]; then
    if [ ${force_overwrite} == yes ] || [ ${force_overwrite} == true ]; then
        cat /dev/null >"${fetchmail_conf_path}"
    else
        echo "fetchmail.conf already exists, you --force to overwrite"
        unlock_and_exit
    fi
fi

cat >"${fetchmail_conf_path}" <<EOF
set logfile "${fetchmail_log_path}"
set invisible
set no bouncemail
poll ${ext_hostname}
port ${ext_port}
auth any
proto ${ext_proto}
user "${ext_user}"
password ${ext_password}
${ssl_config}
${keep}
fetchlimit ${fetch_limit_count}
mda "/usr/bin/procmail -m ${procmail_conf_path}"
EOF

chown vmail:vmail "${fetchmail_conf_path}"
chmod 600 "${fetchmail_conf_path}"

#######################################
########### procmail config ###########
#######################################

if [ -e "${procmail_conf_path}" ]; then
    if [ ${force_overwrite} == yes ] || [ ${force_overwrite} == true ]; then
        cat /dev/null >"${procmail_conf_path}"
    else
        echo "fetchmail.conf already exists, you --force to overwrite"
        unlock_and_exit
    fi
fi

cat >"${procmail_conf_path}" <<EOF
MAILDIR="${procmail_maildir_path}/"
DEFAULT="${procmail_default_path}/"
LOGFILE="${procmail_log_path}"
VERBOSE=on

:0
EOF

chown vmail:vmail "${procmail_conf_path}"
chmod 600 "${procmail_conf_path}"

#########################################
########### fetchmail logging ###########
#########################################

if [ ! -e "${fetchmail_log_path}" ]; then
    touch "${fetchmail_log_path}"
fi

# /var/log/fetchmail/<domain>-<username>.log
# dir
fetchmail_log_links_path="${log_links_path}/fetchmail"
if [ ! -d "${fetchmail_log_links_path}" ]; then
    mkdir -p "${fetchmail_log_links_path}"
fi

# link to logfile
fetchmail_log_links_path="${fetchmail_log_links_path}/${my_domain}-${local_username}.log"
if [ ! -e "${fetchmail_log_links_path}" ]; then
    ln -s "${fetchmail_log_path}" "${fetchmail_log_links_path}"
fi

########################################
########### procmail logging ###########
########################################

if [ ! -e "${procmail_log_path}" ]; then
    touch "${procmail_log_path}"
fi

# link /var/log/fetchmail/<domain>-<username>.log
# dir
procmail_log_links_path="${log_links_path}/procmail"
if [ ! -d "${procmail_log_links_path}" ]; then
    mkdir -p "${procmail_log_links_path}"
fi

# link to logfile
procmail_log_links_path="${procmail_log_links_path}/${my_domain}-${local_username}.log"
if [ ! -e "${procmail_log_links_path}" ]; then
    ln -s "${procmail_log_path}" "${procmail_log_links_path}"
fi

unlock_and_exit
