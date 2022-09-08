#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# shared-functions.sh:
# Base library of functions for the scripts used to manage all prerequisite
# serpent-os tooling repositories

RUN_DIR="${PWD}"

# Download via HTTPS (negotiates faster than SSH), push via SSH
SSH_PREFIX="git@github.com:serpent-os"
HTTPS_PREFIX="https://github.com/serpent-os"

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

# check that the directory given in ${1} exists and is a git repo
function isGitRepo ()
{
    if [[ -d "${1}"/.git/ ]]; then
        return 0 # "success"
    else
        return 1 # ! "success"
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
        failMsg "\n  Git repo ${PWD} contains uncommitted changes.\n  '- Aborting!\n"
    fi
}


PREREQ_NOT_FOUND=0
# Check for all tools, libraries and headers before bailing
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

    echo -e "\nChecking for necessary tools/binaries"
    # 'all keys in the bin associative array'
    for b in "${!bin[@]}" ; do
        command -v "${bin[$b]}" > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${b} (${bin[$b]}) not found in \$PATH."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${b} (${bin[$b]})"
        fi
    done

    echo -e "\nChecking for necessary development libraries and headers (-devel packages):"
    # Key is the .pc name (without extension) -- e.g. libcurl.pc -> libcurl
    # Value is the invocation parameters for a successful pkg-config match
    # FIXME: Determine and set correct minimum versions
    declare -A pc
    pc[libcurl]='--atleast-version=7.5'
    pc[libxxhash]='--atleast-version=0.0.1'
    pc[libzstd]='--atleast-version=1'
    #pc[rocksdb]='--atleast-version=6.22'
    # upstream doesn't ship a .pc file -- it's patched in on major distros
    #pc[lmdb]='--atleast-version=0.9'

    for p in ${!pc[@]}; do
        echo "- ${p} -devel package:"
        pkg-config --exists ${p}
        if [[ ! $? -eq 0 ]]; then
            echo " - ${p} -devel package not found."
            PREREQ_NOT_FOUND=1
        else
            echo " - checking version requirement (${pc[$p]}):"
            pkg-config --print-errors ${pc[$p]} ${p}
            if [[ ! $? -eq 0 ]]; then
                echo "  - ${p} -devel package installed, but does not meet version requirement."
                PREREQ_NOT_FOUND=1
            else
                echo "  - found ${p}.pc file which meets version requirement."
            fi
        fi
    done

    # For packages which typically don't have .pc files
    declare -A header
    header[glibc]='gnu/lib-names-64.h'
    header[kernel]='linux/elf.h'
    header[lmdb]='lmdb.h'

    for h in ${!header[@]}; do
        find /usr/include -name ${header[$h]} > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${h} -devel headers (${header[$h]}) not found."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${h} -devel headers (/usr/include/${header[$h]})"
        fi
    done

    # This is by far the slowest check, so leave it for last
    # - it ensures runtime access to C libraries from Dlang C bindings
    declare -A lib
    lib[curl]=libcurl.so.4
    #lib[rocksdb]=librocksdb.so
    lib[lmdb]=liblmdb.so*
    lib[xxhash]=libxxhash.so.0
    lib[zstd]=libzstd.so.1

    echo -e "\nChecking for the existence of non-development (runtime) libraries"
    for l in ${!lib[@]}; do
        find /usr/lib{,64} -name ${lib[$l]} 2>/dev/null |xargs stat &>/dev/null
        if [[ ! $? -eq 0 ]]; then
            echo "- ${l} runtime library (${lib[$l]}) not found."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${l} runtime library (${lib[$l]})"
        fi
    done

    if [[ ${PREREQ_NOT_FOUND} -gt 0 ]]; then
        failMsg "\nPlease ensure that all necessary tools, libraries and headers are installed.\n"
    else
        echo -e "\nFound all necessary tools, libraries and headers.\n"
    fi
}

# Emit message if ${HOME}/bin is not in $PATH
function checkPath ()
{
    if [[ ! "${PATH}" =~ "${HOME}/bin" ]]; then
        echo -e "\nRemember to add \${HOME}/bin to \$PATH \!\n"
    fi
}

# build tool (= dir under git control) specified in ${1}
# this function is assumed to be run from the directory
# below the individual clones (clone root)
function buildTool ()
{
    # Limit memory consumption to <10GiB worst case when compiling the
    # drafter/ licence stuff in boulder, due to each active ldc2
    # instance using up to 1.6GiB resident memory.
    if [[ "${1}" == "boulder" && $(nproc) -gt 4 ]]; then
        local JOBS="-j6"
    fi

    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a serpent tooling repo?"

    pushd "${1}"
    # Make the user deal with unclean git repos
    checkGitStatusClean

    # We want to unconditionally (re)configure the build, if a previous
    # build/ dir exists.
    #
    # ${JOBS:-} is expanded to nothing if JOBS isn't set above
    # which implies using the number of available hardware threads
    ( meson setup --wipe build/ || meson setup build/ ) && \
    meson compile -C build/ ${JOBS:-} && \
    ln -svf "${PWD}/build/${1}" "${HOME}/bin/"
    # error out noisily if any of the build steps fail
    if [[ $? -gt 0 ]]; then
        failMsg "\n  Building ${1} failed!\n  '- Aborting!\n"
    fi
    # boulder is "special" (... *ahem* ...)
    if [[ "${1}" == "boulder" ]]; then
        ln -svf "${PWD}/build/source/${1}/${1}" "${HOME}/bin/"
    fi
    popd
}

function buildAllTools ()
{
    # We can do this because this invocation doesn't touch existing
    # bin dir/symlink
    mkdir -pv ${HOME}/bin
    echo -e "\nBuilding moss, moss-container and boulder...\n"
    for repo in moss moss-container boulder; do
        buildTool "$repo"
    done
    echo -e "\nSuccessfully built moss, moss-container and boulder.\n"
    echo -e "Created the following symlinks:\n"
    ls -l ${HOME}/bin/{moss,moss-container,boulder}
    checkPath
}

function cleanTool ()
{
    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a serpent tooling repo?"

    pushd "${1}"
    if [[ -d build/ ]]; then
        echo -e "\nCleaning ${1}/build/ ...\n"
        meson compile --clean -C build/
        echo -e "\nDone.\n"
    else
        echo -e "\nCan't clean non-existing ${1}/build/ directory.\n"
    fi
    popd
}

function cleanAllTools ()
{
    echo -e "\nRunning 'meson compile --clean' for all serpent repos...\n"
    for repo in ${CORE_REPOS[@]}; do
        cleanTool "$repo"
    done

}

REPO_FAIL=()
# Will likely fail if the repo path exists locally,
# so this may not be a good solution
function cloneRepo()
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
        echo -e "\n- failed to git clone --recurse-submodules ${1},\n"
        echo -e "-- NOT attempting to set push URI for ${1}.\n"
        REPO_FAIL+=("${1}")
    fi
}

# Takes a single argument, which is the name of an existing known dir
# with a .git/ dir
function pullRepo()
{
    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a valid repo for git pull? Aborting."

    pushd "${1}"
    checkGitStatusClean

    git pull --rebase --recurse-submodules
    if [[ $? -eq 0 ]]; then
        echo -e "\nChecking ${1} SSH push URI...\n"
        local PUSH_URI="$(git remote get-url --push origin)"
        # Don't touch the push URI if the user has manually re-configured it
        # to a different SSH push URI
        if [[ "${PUSH_URI}" =~ "git@github.com:" && ! "${PUSH_URI}" =~ "${SSH_PREFIX}" ]]; then
            echo "- Push URI for ${1} has been changed manually, not attempting to reset it."
        else
            # Reset push URI on the off chance that the current repo
            # has been recloned manually
            echo "- Resetting ${1} push URI to default..."
            git remote set-url --push origin "${SSH_PREFIX}/${1}.git"
        fi
        git remote -v
        echo ""
    else
        # We deliberately drop into the offending git repo
        echo -e "\n- failed to git pull --rebase --recurse-submodules ${1}"
        echo -e "-- NOT attempting to set push URI for ${1}.\n"
        REPO_FAIL+=("${1}")
    fi
    popd
    checkoutMainBranch ${1}
}

# TODO: Switch back to the main branches once the moss LMDB
#       port is ready. Use the 'legacy-moss-branch' for now.
function checkoutMainBranch ()
{
    if [[ ( "${1}" == "moss-core" || "${1}" == "moss-db" || "${1}" == "moss-deps" ) && -d "${1}" ]]; then
        echo -e "\nChecking out the ${1} 'main' branch"
        git -C "${1}" checkout legacy-moss-branch || \
            failMsg "- failed to git checkout the 'main' branch for ${1}!"
    fi
    echo ""
}



function updateRepo ()
{
    isGitRepo "${1}" && pullRepo "${1}" || cloneRepo "${1}"
}

function updateAllRepos ()
{
    echo -e "\nUpdating all serpent tooling repos to newest upstream version...\n"
    for repo in ${CORE_REPOS[@]}; do
        updateRepo "$repo"
    done
    # If we have a non-empty REPO_FAIL array, we're in trouble
    [[ ${#REPO_FAIL[@]} -gt 0 ]] && failMsg "ERROR:\n\nFailed to update repos:\n\n${REPO_FAIL[@]}\n"

    echo -e "List of directories in ${RUN_DIR}:\n"
    ls -1F --group-directories-first ${RUN_DIR}

    echo -e "\nAll serpent tooling repos successfully updated to newest upstream version.\n"
}

function pushRepo()
{
    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a valid repo for git push? Aborting."

    pushd "${1}"
    checkGitStatusClean

    git push
    if [[ $? -gt 0 ]]; then
        # We deliberately drop into the offending git repo
        failMsg "Failed to run git push for ${1}. Aborting."
    fi
    popd
}

function pushAllRepos ()
{
    echo -e "\nPushing all local commits to upstream repos...\n"
    for repo in ${CORE_REPOS[@]}; do
        pushRepo "$repo"
    done
    echo -e "\nAll serpent tooling repos successfully updated to newest upstream version.\n"
}

function updateUsage ()
{
    MSG="
    To check if all prerequisites are available on the local system,
    run 'onboarding/check-prereqs.sh'.

    To build the currently checked out versions of the Serpent OS tooling,
    run 'onboarding/build-all.sh'.

    Developers with commit access can use 'onboarding/push-all.sh' to push all
    local changes in sequence when working on feature/topic branches.

    To update all repos and build the newest version of the Serpent OS tooling,
    simply run './update.sh' from the serpent-os/ clone root.

    Most people should only need to use './update.sh'.
    "
    echo -e "${MSG}"
}
