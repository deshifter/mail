#!/usr/bin/env bash

set -o errexit

lockfile="/tmp/fetchmail_create_job.lock"

# normal exit
function normal_exit() {
    rm -f ${lockfile}
    exit
}


# check permisions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    normal_exit
fi


# lock file
if [ ! -e "${lockfile}" ]; then
    touch ${lockfile}
else
    echo "Process is locked"
    exit
fi


# maildir path
maildir_path="/home/mail"

if [ ! -d "${maildir_path}" ]; then
    echo "Can't open ${maildir_path}: Directory nonexistent"
    normal_exit
fi


# local mail server
my_domain=$(hostname -d)
# external mail server
ext_hostname="mail.termoxid.com"
ext_use_ssl=no
ext_port=143
ext_proto="imap"
ext_username=
ext_password=
# keep messages on external server
keep_on_server=no
# max count mails for one connection
fetch_limit_count=5
# overwrite existed config files
force_overwrite=false


# check paramets
while [ -n "$1" ]; do
    case "$1" in
    -F | --force)
        force_overwrite=true
        shift
        ;;
    -f | --from)
        ext_username="$2"
        shift
        ;;
    -p | --password)
        ext_password="$2"
        shift
        ;;
    -t | --to)
        local_username="$2"
        shift
        ;;
    *) ;;
    esac
    shift
done

if [ -z "${ext_username}" ] || [ -z "${ext_password}" ] || [ -z "${local_username}" ]; then
    echo "Too few arguments. Use: ./create_job.sh --from EXT_USERNAME --password EXT_PASSWORD --to LOCAL_USERNAME"
    normal_exit
fi


# local user's mailbox path
mailbox_path="${maildir_path}/${my_domain}/${local_username}@${my_domain}"

if [ ! -d "${mailbox_path}" ]; then
    echo "Cannot open ${mailbox_path}: Directory nonexistent"
    normal_exit
fi


# fetchmail config file
fetchmail_conf_path="${mailbox_path}/fetchmail-${ext_username}.conf" #TODO ext_email

if [ -e "${fetchmail_conf_path}" ] && [ ${force_overwrite} != true ]; then
    echo "fetchmail.conf already exists, you --force to overwrite"
    normal_exit
fi

chown vmail:vmail "${fetchmail_conf_path}"
chmod 600 "${fetchmail_conf_path}"

# procmail config file
procmail_conf_path="${mailbox_path}/procmail-${ext_username}.conf"

if [ -e "${procmail_conf_path}" ] && [ ${force_overwrite} != true ]; then
    echo "procmail.conf already exists, you --force to overwrite"
    normal_exit
fi

chown vmail:vmail "${procmail_conf_path}"
chmod 600 "${procmail_conf_path}"


# fetchmail log file
fetchmail_log_path="${mailbox_path}/fetchmail.log"

if [ ! -e "${fetchmail_log_path}" ]; then
    touch "${fetchmail_log_path}"
    chown vmail:vmail "${fetchmail_log_path}"
fi

# procmail log file
procmail_log_path="${mailbox_path}/procmail.log"

if [ ! -e "${procmail_log_path}" ]; then
    touch "${procmail_log_path}"
    chown vmail:vmail "${procmail_log_path}"
fi


# fetchmail config file content
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

cat >"${fetchmail_conf_path}" <<EOF
set logfile "${fetchmail_log_path}"
set invisible
set no bouncemail
poll ${ext_hostname}
port ${ext_port}
auth any
proto ${ext_proto}
user "${ext_username}"
password ${ext_password}
${ssl_config}
${keep}
fetchlimit ${fetch_limit_count}
mda "/usr/bin/procmail -m ${procmail_conf_path}"
EOF

# procmail config file content
cat >"${procmail_conf_path}" <<EOF
MAILDIR="${mailbox_path}/"
DEFAULT="${mailbox_path}/"
LOGFILE="${procmail_log_path}"
VERBOSE=on

:0
EOF


# log links path
log_links_path="/var/log"

# fetchmail log file link
fetchmail_log_links_path="${log_links_path}/fetchmail"
if [ ! -d "${fetchmail_log_links_path}" ]; then
    mkdir -p "${fetchmail_log_links_path}"
fi

fetchmail_log_links_path="${fetchmail_log_links_path}/${my_domain}-${local_username}.log"
if [ ! -e "${fetchmail_log_links_path}" ]; then
    ln -s "${fetchmail_log_path}" "${fetchmail_log_links_path}"
fi

# procmail log file link
procmail_log_links_path="${log_links_path}/procmail"
if [ ! -d "${procmail_log_links_path}" ]; then
    mkdir -p "${procmail_log_links_path}"
fi

procmail_log_links_path="${procmail_log_links_path}/${my_domain}-${local_username}.log"
if [ ! -e "${procmail_log_links_path}" ]; then
    ln -s "${procmail_log_path}" "${procmail_log_links_path}"
fi

# normal termination
echo "normal termination"
normal_exit
