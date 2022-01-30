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
    if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "-?" ]]; then
        echo "Usage: git-clone.sh [--https]"
        echo ""
        echo -e "Unless you have commit access to the 'gitlab.com/serpent-os/core' subgroup, use the '--https' argument.\n"
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

checkGit=0
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    echo -e "Cloning ${1}..."
    git clone --recurse-submodules ${1} || { echo "- failed to clone ${1}?" && checkGit=1; }
    echo ""
}

# Because not doing so sucks
checkHelp
# Run checks
checkPrereqs

# Use ssh by default for convenience -- normal users will error out here
CORE_PREFIX="git@gitlab.com:serpent-os/core"

if [[ ${1} == '--https' ]]; then
    echo -e "Option --https was supplied, using https for git clone...\n"
    CORE_PREFIX="https://gitlab.com/serpent-os/core"
else
    echo -e "Option --https was NOT supplied, using ssh for git clone...\n"
fi

CORE_REPOS=(boulder moss moss-config moss-container moss-core moss-db moss-deps moss-fetcher moss-format moss-vendor serpent-style)

for repo in ${CORE_REPOS[@]}; do
    gitClone "${CORE_PREFIX}/${repo}.git"
done

[[ checkGit -gt 0 ]] && failMsg "One or more git repositories couldn't be cloned."

echo -e "List of directories in ${RUN_DIR}:\n"
ls -1F --group-directories-first ${RUN_DIR}
echo ""
