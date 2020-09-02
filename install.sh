#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# create fetch job
source "./fetchmail/create_job.sh"
