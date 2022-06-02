#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# shared-functions.sh:
# Base library of functions for git-clone.sh and git-pull.sh scripts
# used to manage all prerequisite serpent-os tooling repositories

RUN_DIR="${PWD}"

# Download via HTTPS (negotiates faster than SSH), push via SSH
SSH_PREFIX="git@gitlab.com:serpent-os/core"
HTTPS_PREFIX="https://gitlab.com/serpent-os/core"

CORE_REPOS=(
    boulder
    moss
    moss-config
    moss-container
    moss-core
    moss-db
    moss-deps
    moss-fetcher
    moss-format
    moss-vendor
)

function failMsg()
{
    echo -e "$*"
    exit 1
}

# check that the directory given in $1 exists and is a git repo
function isGitRepo ()
{
    if [[ -d "$1"/.git/ ]]; then
        return 0 # "succes"
    else
        return 1 # ! "succes"
    fi
}

# Should be run from within a known good git repo
function checkGitStatusClean ()
{
    # we don't care about non-tracked files in git-status --short output
    local GIT_STATUS="$(git status --short |grep -v ??)"
    if [[ "$GIT_STATUS" == "" ]]; then
        return 0
    else
        failMsg "Git repo ${PWD} contains uncommitted changes. Aborting"
    fi
}


# Check for all tools, libraries and headers before bailing
PREREQ_NOT_FOUND=0
function checkPrereqs()
{
    # Bash associative arrays are well suited for this kind of thing
    declare -A bin
    bin['pkg-config tool']=pkg-config
    bin['Binutils']=ld
    bin['C compiler']=cc
    bin['CMake build tool']=cmake
    bin['Codespell python tool']=codespell
    bin['Dlang code formatter']=dfmt
    bin['Dlang package manager']=dub
    bin['GNU Awk interpreter']=gawk
    bin['Git version control tool']=git
    bin['LDC D compiler']=ldc2
    bin['Meson build tool']=meson
    bin['Ninja build tool']=ninja

    echo -e "\nChecking for necessary tools..."
    #'all keys in the bin associative array'
    for b in "${!bin[@]}" ; do
        command -v "${bin[$b]}" > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${b} (${bin[$b]}) not found in \$PATH."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${b} (${bin[$b]})"
        fi
    done

    echo "Checking for necessary libraries and development headers..."
    # Key is the .pc name (without extension) -- e.g. libcurl.pc -> libcurl
    # Value is the invocation parameters for a successful pkg-config match
    # FIXME: Determine and set correct minimum versions
    declare -A pc
    pc[libcurl]='--atleast-version=7.5'
    pc[libxxhash]='--atleast-version=0.0.1'
    pc[libzstd]='--atleast-version=1'
    pc[rocksdb]='--atleast-version=6.22'

    for p in ${!pc[@]}; do
        pkg-config --print-errors --exists ${p} && pkg-config --print-errors ${pc[$p]} ${p}
        if [[ ! $? -eq 0 ]]; then
            echo "- ${p} -devel package not found/doesn't meet version requirement (${pc[$p]})."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${p}.pc file"
        fi
    done

    # For packages which typically don't have .pc files
    declare -A header
    header[kernel]='linux/elf.h'
    header[glibc]='gnu/lib-names-64.h'

    for h in ${!header[@]}; do
        find /usr/include -name ${header[$h]} > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${h} headers (${header[$h]}) not found."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${h} headers (/usr/include/${header[$h]})"
        fi
    done

    # This is by far the slowest check, so leave it for last
    # - it ensures runtime access to C libraries from Dlang C bindings
    declare -A lib
    lib[curl]=libcurl.so.4
    lib[rocksdb]=librocksdb.so.6
    lib[xxhash]=libxxhash.so.0
    lib[zstd]=libzstd.so.1

    for l in ${!lib[@]}; do
        find /usr/lib{,64} -name ${lib[$l]} > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${l} library (${lib[$l]}) not found."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${l} library (${lib[$l]})"
        fi
    done

    if [[ ${PREREQ_NOT_FOUND} -gt 0 ]]; then
        failMsg "\nPlease ensure that all necessary tools, libraries and headers are installed.\n"
    else
        echo -e "\nFound all necessary tools, libraries and headers.\n"
    fi
}


GIT_CLONE_FAIL=()
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    # We want to run this from a clean clone root dir that isn't a git repo
    isGitRepo . && \
    failMsg "Found a .git/ dir -- please run ${0} from the (unversioned) base serpent-os/ dir."

    echo -e "Cloning ${HTTPS_PREFIX}/${1}.git..."
    git clone --recurse-submodules "${HTTPS_PREFIX}/${1}.git"

    # Only set up push URI on successful clone
    if [[ $? -eq 0 ]]; then
        echo -e "\nSetting up ${1} SSH push URI...\n"
        git -C "${1}" remote set-url --push origin "${SSH_PREFIX}/${1}.git"
        git -C "${1}" remote -v
        echo ""
    else
        echo -e "\n- failed to git clone ${1}, not attempting to set push URI.\n"
        GIT_CLONE_FAIL+=("${1}")
    fi
}

function checkAndCloneFresh ()
{
    echo -e "Base pull URI: ${HTTPS_PREFIX}"
    echo -e "Base push URI: ${SSH_PREFIX}\n"

    for repo in ${CORE_REPOS[@]}; do
        gitClone "${repo}"
    done

    # If we have a non-empty GIT_CLONE_FAIL array, we're in trouble
    [[ ${#GIT_CLONE_FAIL[@]} -gt 0 ]] && failMsg "ERROR:\n\nFailed to clone:\n\n${failClone[@]} !"

    echo -e "List of directories in ${RUN_DIR}:\n"
    ls -1F --group-directories-first ${RUN_DIR}
    echo ""
}

# build tool (= dir under git control) specified in $1
# this function is assumed to be run from the directory
# below the individual clones (clone root)
function buildSerpentTool ()
{
    isGitRepo "$1" || \
    failMsg "$1 does not appear to be a serpent tooling repo?"

    pushd "$1"
    # Make the user deal with unclean git repos
    checkGitStatusClean
    # We want to unconditionally (re)configure the build
    meson setup build/ && meson configure build/ && \
    meson compile -C build/ && \
    ln -svf "${PWD}/build/$1" "${HOME}/bin/"
    popd
}

function buildAllSerpentTools ()
{
    echo -e "\nBuilding moss, moss-container and boulder...\n"
    for repo in moss moss-container boulder; do
        buildSerpentTool "$repo"
    done
    echo -e "\nSuccessfully built moss, moss-container and boulder.\n"
}

# Takes a single argument, which is the name of an existing known dir
# with a .git/ dir
function pullExistingSerpentRepo()
{
    isGitRepo "$1" || \
    failMsg "$1 does not appear to be a valid repo for git pull? Aborting."

    pushd "$1"
    checkGitStatusClean

    git pull --rebase --recurse-submodules
    if [[ $? -gt 0 ]]; then
        # We deliberately drop into the offending git repo
        failMsg "Failed to run git pull --rebase --recurse-submodules for $1. Aborting."
    fi
    popd
}

function pullAllSerpentRepos ()
{
    echo -e "\nUpdating all serpent tooling repos to newest upstream version...\n"
    for repo in ${CORE_REPOS[@]}; do
        pullExistingSerpentRepo "$repo"
    done
    echo -e "\nAll serpent tooling repos successfully updated to newest upstream version.\n"
}

function pushExistingSerpentRepo()
{
    isGitRepo "$1" || \
    failMsg "$1 does not appear to be a valid repo for git push? Aborting."

    pushd "$1"
    checkGitStatusClean

    git push
    if [[ $? -gt 0 ]]; then
        # We deliberately drop into the offending git repo
        failMsg "Failed to run git push for $1. Aborting."
    fi
    popd
}

function pushAllSerpentRepos ()
{
    echo -e "\nPushing all local commits to upstream repos...\n"
    for repo in ${CORE_REPOS[@]}; do
        pushExistingSerpentRepo "$repo"
    done
    echo -e "\nAll serpent tooling repos successfully updated to newest upstream version.\n"
}
