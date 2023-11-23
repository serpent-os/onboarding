#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Be helpful if the user supplies an argument
if [[ -n "${1}" ]]; then
    cat << EOF

Usage: update-all.sh

Clone or pull+rebase all the Serpent OS tool repositories.

Upon successful clone/pull operations, check prerequisites
and (re)build the serpent tooling if the check passes.

NB: Please run the script from the serpent-os/ git clone root.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "${0}")

source "${ONBOARDING_DIR}/shared-functions.sh"

# fail up-front according to the principle of least astonishment
checkPrereqs && updateAllRepos && time ( buildAllDLangTools && buildRustTools )
updateUsage
