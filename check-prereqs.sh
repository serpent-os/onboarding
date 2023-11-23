#!/usr/bin/env bash
#
# SPDX-License-Identifier: MPL-2.0
#
# Copyright: © 2023 Serpent OS Developers
#

# Initial prerequisite check for the ability to build the
# Serpent OS Dlang tooling

# Be helpful if the user supplies an argument
if [[ -n "${1}" ]]; then
    cat << EOF

Usage: check-prerequisites.sh

Check if all prerequisites for building the Serpent OS tooling are present.

EOF
    exit 0
fi

# ensure we get can source the shared functions properly
ONBOARDING_DIR=$(dirname "${0}")

source "${ONBOARDING_DIR}/shared-functions.sh"

checkPrereqs
