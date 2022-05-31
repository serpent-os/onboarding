#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Initial setup of Serpent OS Dlang repos for development purposes

# Be helpful if the user supplies an argument
if [[ -n "$1" ]]; then
    cat << EOF

Usage: clone-all.sh

Clone all current Serpent OS (https://serpentos.com) tool repositories.

NB: Please run the script from an empty serpent-os/ base directory.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "$0")

source "${ONBOARDING_DIR}/shared-functions.sh"

checkAndCloneFresh
