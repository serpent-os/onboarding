#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Be helpful if the user supplies an argument
if [[ -n "${1}" ]]; then
    cat << EOF

Usage: clean-all.sh

Run 'meson compile --clean' for all Serpent OS tool repos.

NB: Please run the script from the serpent-os/ clone root directory containing
    the Serpent OS core git repos as cloned by 'clone-all.sh'.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "${0}")

source "${ONBOARDING_DIR}/shared-functions.sh"

cleanAllTools
