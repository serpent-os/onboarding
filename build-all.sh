#!/usr/bin/env bash
#
# SPDX-License-Identifier: MPL-2.0
#
# Copyright: © 2023 Serpent OS Developers
#

# Be helpful if the user supplies an argument
if [[ -n "${1}" ]]; then
    cat << EOF

Usage: build-all.sh

Build the 'libmoss', 'moss-service', 'avalanche', 'summit' and 'vessel'
Serpent OS services.

NB: Please run the script from the serpent-os/ clone root directory containing
    the Serpent OS core git repos as cloned by 'clone-all.sh'.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "${0}")

source "${ONBOARDING_DIR}/shared-functions.sh"

buildAllDlangTools
