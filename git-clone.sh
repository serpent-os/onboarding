#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Initial setup of Serpent OS Dlang repos for development purposes

RUN_DIR="${PWD}"

function failMsg()
{
        echo -e $*
        exit 1
}

# Support "-h", "--help" and "-?" for convenience
function checkHelp()
{
    if [[ "-h" =~ "$1" || "--help" =~ "$1" || "-?" =~ "$1" ]]; then
        echo "Usage: git-clone.sh"
        echo ""
        echo "Clone all current Serpent OS (https://serpentos.com) tool repositories."
        echo ""
        echo -e "Please run the script from an empty serpent-os/ base directory.\n"
        exit 0
    fi
}

# Check for all tools before bailing
checkPrereqs=0
function checkPrereqs()
{
    # Check that the script was run from the shared serpent-os/ dir and not from a git-controlled dir
    [[ -d .git/ ]] && failMsg "Found a .git/ dir -- please run ${0} from the (unversioned) base serpent-os/ dir."

    echo -e "\nChecking for necessary tools..."
    for tool in dub git ldc2 meson; do
        command -v ${tool} 2>&1 > /dev/null
        if [[ ! $? -eq 0 ]]; then
            echo "- ${tool} not found? Please install it."
            checkPrereqs=1
        else
            echo "- found ${tool}"
        fi
    done

    if [[ ${checkPrereqs} -gt 0 ]]; then
       failMsg "\nPlease ensure that necessary tools are installed.\n"
    else
       echo -e "\nFound all necessary tools, continuing...\n"
    fi
}

checkTransport ()
{
    local TEST_DIR="/tmp/serpent-os"
    # We need a clean dir
    if [[ -d ${TEST_DIR} ]]; then
        rm -rf "${TEST_DIR}" || failMsg "Please remove '/tmp/serpent-os before running $0 again.\n"
    fi
    mkdir -pv "${TEST_DIR}" || failMsg "Cannot create ${TEST_DIR}, please check permissions.\n"
    pushd "${TEST_DIR}"

    # try to fetch via ssh
    local REPO="${CORE_PREFIX}/onboarding.git"
    echo -e "\nAttempting to clone ${REPO}...\n"
    git clone "${REPO}"

    # We need a plan B
    if [[ ! $? -eq 0 ]]; then
        echo -e "SSH transport didn't appear to work; switching to https transport...\n"
        CORE_PREFIX="https://gitlab.com/serpent-os/core"
        REPO="${CORE_PREFIX}/onboarding.git"
        gitClone ${REPO}
    fi

    # Unconditionally delete the test dir
    popd
    rm -rf "${TEST_DIR}" || failMsg "Failed to clean up ${TEST_DIR}, please remove manually.\n"

    if [[ checkGit -gt 0 ]]; then
        failMsg "Couldn't clone ${REPO}, giving up."
    fi

    # If we make it this far, checkGit is 0
}

checkGit=0
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    echo -e "Cloning ${1}..."
    git clone --recurse-submodules ${1} || { echo "- failed to clone ${1}?" && checkGit=1; }
    echo ""
}


# Use ssh by default for convenience -- normal users will error out here
function main ()
{
    # Because not doing so sucks
    checkHelp
    # Run checks
    checkPrereqs
    # Get some sort of transportDoes SSH work?
    checkTransport

    if [[ -z "${CORE_PREFIX}" ]]; then
        failMsg "\nCORE_PREFIX needs to be set to a valid upstream URI.\n"
    else
        echo -e "\nUsing ${CORE_PREFIX} as upstream prefix URI...\n"
    fi

    CORE_REPOS=(boulder moss moss-config moss-container moss-core moss-db moss-deps moss-fetcher moss-format moss-vendor serpent-style)

    # Test whether SSH transport works

    for repo in ${CORE_REPOS[@]}; do
        gitClone "${CORE_PREFIX}/${repo}.git"
    done

    [[ checkGit -gt 0 ]] && failMsg "One or more git repositories couldn't be cloned."

    echo -e "List of directories in ${RUN_DIR}:\n"
    ls -1F --group-directories-first ${RUN_DIR}
    echo ""
}

# Try SSH transport first
CORE_PREFIX="git@gitlab.com:serpent-os/core"
main
