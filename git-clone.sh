#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Initial setup of Serpent OS Dlang repos for development purposes

RUN_DIR="${PWD}"

# Be helpful if the user supplies an argument
if [[ -n "$1" ]]; then
    echo "Usage: git-clone.sh"
    echo ""
    echo "Clone all current Serpent OS (https://serpentos.com) tool repositories."
    echo ""
    echo -e "Please run the script from an empty serpent-os/ base directory.\n"
    exit 0
fi

function failMsg()
{
        echo -e $*
        exit 1
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

checkGit=0
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    echo -e "Cloning ${HTTPS_PREFIX}/${1}.git..."
    git clone --recurse-submodules "${HTTPS_PREFIX}/${1}.git"
    # Only set up push URI on successful clone
    if [[ $? -eq 0 ]]; then
        echo -e "\nSetting up SSH push URI...\n"
        pushd "${1}"
        git remote set-url --push origin "${SSH_PREFIX}/${1}.git"
        git remote -v
        popd
        echo ""
    else
        echo -e "\n- failed to clone ${1}, not attempting to set push URI.\n"
        checkGit=1
    fi
}

function main ()
{
    # Run checks
    checkPrereqs

    # Download via HTTPS (negotiates faster than SSH), push via SSH
    SSH_PREFIX="git@gitlab.com:serpent-os/core"
    HTTPS_PREFIX="https://gitlab.com/serpent-os/core"

    echo -e "Using ${HTTPS_PREFIX} as base pull URI...\n"
    echo -e "Using ${SSH_PREFIX} as base push URI...\n"

    CORE_REPOS=(boulder moss moss-config moss-container moss-core moss-db moss-deps moss-fetcher moss-format moss-vendor serpent-style)

    for repo in ${CORE_REPOS[@]}; do
        gitClone "${repo}"
    done

    [[ checkGit -gt 0 ]] && failMsg "One or more git repositories couldn't be cloned."

    echo -e "List of directories in ${RUN_DIR}:\n"
    ls -1F --group-directories-first ${RUN_DIR}
    echo ""
}

main
