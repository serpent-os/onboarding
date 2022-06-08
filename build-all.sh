#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Be helpful if the user supplies an argument
if [[ -n "$1" ]]; then
    cat << EOF

Usage: build-all.sh

Build the 'moss', 'moss-container' and 'boulder' Serpent OS tools.

NB: Please run the script from the serpent-os/ clone root directory containing
    the Serpent OS core git repos as cloned by 'clone-all.sh'.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "$0")

source "${ONBOARDING_DIR}/shared-functions.sh"

buildAllTools
