#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Pull all Serpent OS Dlang repos checked out by clone-all.sh

# Be helpful if the user supplies an argument
if [[ -n "$1" ]]; then
    cat << EOF

Usage: pull-all.sh

Pull and rebase all existing clones of the Serpent OS tool repositories.

NB: Please run the script from the serpent-os/ git clone root.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "$0")

source "${ONBOARDING_DIR}/shared-functions.sh"

pullAllSerpentRepos
