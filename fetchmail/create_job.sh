#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

touch /tmp/mail/fetchmail_create_job.lock

# maildir path
maildir_path="/home/mail"

if [ ! -d "${maildir_path}" ]; then
    echo "cannot open ${maildir_path}: Directory nonexistent"
    exit
fi

# log links path
log_links_path="${maildir_path}/.logs"

# local mail server
my_domain=$(hostname -d)

# external mail server
ext_hostname="mail.termoxid.com"
ext_port=143
ext_proto="imap"
#
use_ssl=no
keep_on_server=no
fetch_limit_count=5

target_username=
ext_user=
ext_password=

force_overwrite=false

while [ -n "$1" ]
do
    case "$1" in
        -F | --force) force_overwrite=true
        shift ;;
        -f | --from) ext_user="$2"
        shift ;;
        -p | --password) ext_password="$2"
        shift ;;
        -t | --to) target_username="$2"
        shift ;;
        *) ;;
    esac
    shift
done

if [ -z "${ext_user}" ] || [ -z "${ext_password}" ] || [ -z "${target_username}" ]; then
    echo "Too few arguments. Use: ./install.sh -f USER -p PASSWORD -t USERNAME"
    exit
fi

mailbox_path="${maildir_path}/${my_domain}/${target_username}@${my_domain}"

if [ ! -d "${mailbox_path}" ]; then
    echo "cannot open ${mailbox_path}: Directory nonexistent"
    exit
fi

if [ $use_ssl = yes ] || [ $use_ssl = true ]; then
    ssl_config="ssl"
fi

if [ $use_ssl = no ] || [ $use_ssl = false ]; then
    ssl_config="sslproto ''"
fi

if [ $keep_on_server = yes ] || [ $keep_on_server = true ]; then
    keep="keep"
fi

if [ $keep_on_server = no ] || [ $keep_on_server = false ]; then
    keep="no keep"
fi


fetchmail_conf_path="${mailbox_path}/fetchmail.conf"
fetchmail_log_path="${mailbox_path}/fetchmail.log"

procmail_conf_path="${mailbox_path}/procmail.conf"
procmail_log_path="${mailbox_path}/procmail.log"

if [ -d "${fetchmail_log_path}" ]; then
    if [ $force_overwrite != yes ] && [ $force_overwrite != true ]; then
        echo "fetchmail.conf already exists, you --force to overwrite"
        exit
    fi
fi

cat > "$fetchmail_conf_path" << EOF
set logfile ${fetchmail_log_path}
set invisible
set no bouncemail
poll $ext_hostname
port $ext_port
auth any
proto $ext_proto
user "$ext_user"
password $ext_password
$ssl_config
$keep
fetchlimit $fetch_limit_count
mda "/usr/bin/procmail -m ${procmail_conf_path}"
EOF

chmod 600 "${fetchmail_conf_path}"
chmod 600 "${procmail_conf_path}"

if [ -e "${fetchmail_log_path}" ]; then
    touch "${fetchmail_log_path}"
fi

if [ -e "${procmail_log_path}" ]; then
    touch "${procmail_log_path}"
fi

procmail_maildir_path="${mailbox_path}"
procmail_default_path="${mailbox_path}"

cat > "${procmail_conf_path}" << EOF
MAILDIR="${procmail_maildir_path}/"
DEFAULT="${procmail_default_path}/"
LOGFILE="${procmail_log_path}"
VERBOSE=on

:0
EOF

fetchmail_log_links_path="${log_links_path}/fetchmail"
if [ ! -d "${fetchmail_log_links_path}" ]; then
    md -p "${fetchmail_log_links_path}"
fi

fetchmail_log_links_path="${fetchmail_log_links_path}/${my_domain}-${target_username}.log"
if [ ! -e "${fetchmail_log_links_path}" ]; then
    ln -s "${fetchmail_log_path}" "${fetchmail_log_links_path}"
fi

procmail_log_links_path="${log_links_path}/procmail"
if [ ! -d "${log_links_path}" ]; then
    md -p "${log_links_path}"
fi

procmail_log_links_path="${procmail_log_links_path}/${my_domain}-${target_username}.log"
if [ ! -e "${procmail_log_links_path}" ]; then
    ln -s "${procmail_log_path}" "${procmail_log_links_path}"
fi
