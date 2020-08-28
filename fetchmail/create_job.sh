#!/usr/bin/env bash

# default config
log_path="/var/log/fetchmail"
# local mail server
int_hostname="domain.local"
# external mail server
ext_poll="imap.example.com"
ext_port=143
ext_proto="imap"


int_username=
ext_user=
ext_password=

while [ -n "$1" ]
do
    case "$1" in
        -f | --from) ext_user="$2"
        shift ;;
        -p | --password) ext_password="$2"
        shift ;;
        -t | --to) int_username="$2"
        shift ;;
        *) ;;
    esac
    shift
done

if [ -z "$ext_user" ] || [ -z "$ext_password" ] || [ -z "$int_username" ]; then
    echo "Too few arguments. Use: ./install.sh -f USER -p PASSWORD -t USERNAME"
    exit
fi

maildir_path="/home/mail/$int_hostname/$int_username@$int_hostname"

if [ ! -e "$maildir_path" ]; then
    echo "cannot open $maildir_path: Directory nonexistent"
    exit
fi

log_path_full="$log_path/$int_hostname/$int_username@$int_hostname.log"

invisiblity=yes
bouncemail=no
use_ssl=yes
keep_on_server=yes

if [ $invisiblity = yes ] || [ $invisiblity = true ]; then
    invisible="set invisible"
fi

if [ $bouncemail = no ] || [ $bouncemail = false ]; then
    no_bouncemail="set no bouncemail"
fi

if [ $use_ssl = yes ] || [ $use_ssl = true ]; then
    ssl="ssl"
fi

if [ $keep_on_server = yes ] || [ $keep_on_server = true ]; then
    keep="keep"
fi

fetchmail_conf=$maildir_path/fetchmail.conf

cat > "$fetchmail_conf" << EOF
set logfile "${log_path_full}"
${invisible}
${no_bouncemail}
poll ${ext_poll}
port ${ext_port}
proto $ext_proto
user "${ext_user}"
password "${ext_password}"
${ssl}
${keep}
mda "/usr/bin/procmail -m ${maildir_path}/procmail.conf"
EOF

chown vmail:vmail "$fetchmail_conf"
chmod 700 "$fetchmail_conf"