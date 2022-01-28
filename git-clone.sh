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
        echo $*
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
       failMsg "Please ensure that necessary tools are installed."
    else
       echo -e "Found all necessary tools, continuing...\n"
    fi
}

checkGit=0
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    echo -e "\nCloning ${1}..."
    git clone ${1} || checkGit=1 echo "- failed to clone ${1}?"
}

# Run checks
checkPrereqs

CORE_PREFIX="git@gitlab.com:serpent-os/core"
BINDING_PREFIX="git@gitlab.com:serpent-os/dlang"

if [[ ${1} =~ '--https' ]]; then
    echo -e "Option --https was supplied, using https for git clone...\n"
    CORE_PREFIX="https://gitlab.com/serpent-os/core"
    BINDING_PREFIX="https://gitlab.com/serpent-os/dlang"
else
    echo -e "Option --https was NOT supplied, using ssh for git clone...\n"
fi

CORE_REPOS=(boulder moss moss-config moss-container moss-core moss-db moss-deps moss-fetcher moss-format serpent-style)
BINDING_REPOS=(elf-d rocksdb-binding xxhash-d zstd-d)


for repo in ${CORE_REPOS[@]}; do
    gitClone "${CORE_PREFIX}/${repo}.git"
done

for repo in ${BINDING_REPOS[@]}; do
    gitClone "${BINDING_PREFIX}/${repo}.git"
done

[[ checkGit -gt 0 ]] && failMsg "One or more git repositories couldn't be cloned."

echo -e "\nList of directories in ${RUN_DIR}:"
ls -1F --group-directories-first ${RUN_DIR}
