#!/usr/bin/env bash
#
# SPDX-License-Identifier: MPL-2.0
#
# Copyright: © 2023 Serpent OS Developers
#

# shared-functions.sh:
# Base library of functions for the scripts used to manage all prerequisite
# serpent-os tooling repositories

## Environment overrides:
#
# Github prefix (useful for when preparing PRs from a user repo)
GH_NAMESPACE="${GH_NAMESPACE:-serpent-os}"
echo -e "\nUsing GH_NAMESPACE: ${GH_NAMESPACE}"
#
# install prefix for tooling (allow environment override)
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"
echo -e "\nUsing INSTALL_PREFIX: ${INSTALL_PREFIX}"
#
## Environment overrides END

# Add escape codes for color
RED='\033[0;31m'
RESET='\033[0m'

# Capture current run-dir
RUN_DIR="${PWD}"

# Download via HTTPS (negotiates faster than SSH), push via SSH
SSH_PREFIX="git@github.com:${GH_NAMESPACE}"
HTTPS_PREFIX="https://github.com/${GH_NAMESPACE}"

# Make it easier to selectively check out branches per project
declare -A CORE_REPOS
#CORE_REPOS['boulder']=main
CORE_REPOS['img-tests']=main
CORE_REPOS['libmoss']=main
CORE_REPOS['moss']=main
CORE_REPOS['moss-container']=main

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
    local GIT_STATUS="$(git -C ${1} status --short |grep -v ??)"
    if [[ "$GIT_STATUS" == "" ]]; then
        return 0
    else
        failMsg "\n  Git repo ${1} contains uncommitted changes.\n  '- Aborting!\n"
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
    bin['Rust Cargo package manager']=cargo
    bin['Codespell python tool']=codespell
    bin['Dlang code formatter']=dfmt
    bin['Dlang package manager']=dub
    bin['Fakeroot tool']=fakeroot
    bin['GNU Awk interpreter']=gawk
    bin['Git version control tool']=git
    bin['Go-task']=go-task
    bin['LDC D compiler v1.32.2']=ldc2
    bin['Meson build tool']=meson
    bin['Ninja build tool']=ninja
    bin['Rust compiler']=rustc
    #bin['Rust code formatter']=rustfmt
    bin['Sudo']=sudo

    echo -e "\nChecking for necessary tools/binaries"
    # 'all keys in the bin associative array'
    for b in "${!bin[@]}" ; do
        # distributions use 'go-task', upstream uses 'task' ¯\_(ツ)_/¯
        local found
        if [[ ${bin[$b]} =~ "go-task" ]]; then
            found=$(command -v task || command -v go-task)
        elif [[ ${bin[$b]} == "ldc2" ]]; then
            local candidate=$(command -v "${bin[$b]}")
            if [[ -n $candidate ]]; then
                local ldc_version=$(ldc2 --version |head -n1 |grep -o '1.32.2')
                if [[ "${ldc_version}" != "1.32.2" ]]; then
                    echo -e "- ${b} (${bin[$b]}) version 1.32.2 ${RED}not found${RESET} in \$PATH."
                    PREREQ_NOT_FOUND=1
                    continue
                else
                    found="$candidate"
                fi
            fi
        else
            found=$(command -v "${bin[$b]}")
        fi
        if [[ -z $found ]]; then
            echo -e "- ${b} (${bin[$b]}) ${RED}not found${RESET} in \$PATH."
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${b} (${found})"
        fi
        unset local
    done

    echo -e "\nChecking for necessary development libraries and headers (-devel packages):"
    # Key is the .pc name (without extension) -- e.g. libcurl.pc -> libcurl
    # Value is the invocation parameters for a successful pkg-config match
    # FIXME: Determine and set correct minimum versions
    declare -A pc
    pc[dbus-1]='--atleast-version=1.14'
    #pc[libgit2]='--atleast-version=1.3.0'
    pc[libcurl]='--atleast-version=7.5'
    pc[libxxhash]='--atleast-version=0.0.1'
    pc[libzstd]='--atleast-version=1'
    pc[mount]='--atleast-version=2.37'
    #pc[rocksdb]='--atleast-version=6.22'
    # upstream doesn't ship a .pc file -- it's patched in on major distros
    #pc[lmdb]='--atleast-version=0.9'

    for p in ${!pc[@]}; do
        echo "- ${p} -devel package:"
        pkg-config --exists ${p}
        if [[ ! $? -eq 0 ]]; then
            echo -e " - ${p} -devel package ${RED}not found.${RESET}"
            PREREQ_NOT_FOUND=1
        else
            echo " - checking version requirement (${pc[$p]}):"
            pkg-config --print-errors ${pc[$p]} ${p}
            if [[ ! $? -eq 0 ]]; then
                echo "  - ${p} -devel package installed, but ${RED}does not meet version requirement.${RESET}"
                PREREQ_NOT_FOUND=1
            else
                echo "  - found ${p}.pc file which meets version requirement."
            fi
        fi
    done

    # For packages which typically don't have .pc files
    declare -A header
    header[glibc]='/usr/include/gnu/lib-names-64.h'
    header[kernel]='/usr/include/linux/elf.h'
    header[lmdb]='/usr/include/lmdb.h'

    for h in ${!header[@]}; do
        if [[ "$h" == "glibc" ]]; then
            # debian and fedora differ here
            ls ${header[$h]} >/dev/null 2>&1 || ls /usr/include/x86_64-linux-gnu/gnu/lib-names-64.h >/dev/null 2>&1
        else
            ls ${header[$h]} >/dev/null 2>&1
        fi
        if [[ ! $? -eq 0 ]]; then
            echo -e "- ${h} -devel headers (${header[$h]}) ${RED}not found.${RESET}"
            PREREQ_NOT_FOUND=1
        else
            echo "- found ${h} -devel headers (${header[$h]})"
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
            echo -e "- ${l} runtime library (${lib[$l]}) ${RED}not found.${RESET}"
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
function buildDLangTool ()
{
    # Conservatively limit memory consumption during compilation of
    # the drafter/ licence stuff in boulder, due to each active ldc2
    # instance using up to 1.6GiB resident memory worst case.
    local THREADS=$(nproc)
    # Assume that at least 2 GiB is available!
    if [[ "${1}" == "boulder" && ${THREADS} -gt 1 ]]; then
        local MEM_AVAILABLE=$(gawk '/MemAvailable/ { GiB = $2/(1024*1024); print GiB }' /proc/meminfo)
        local MAX_JOBS=$(echo "${MEM_AVAILABLE}" |gawk '{ print int($1/1.6) }')
        if [[ ${MAX_JOBS} -lt ${THREADS} ]]; then
            local JOBS="-j${MAX_JOBS}"
            echo -e "\n  INFO: Restricting to ${JOBS} parallel boulder build jobs (Free RAM: ~${MEM_AVAILABLE} GiB)\n"
        else
            echo -e "\n  INFO: Using ${THREADS} parallel boulder build jobs\n"
        fi
    fi

    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a serpent tooling repo?"
    # Make the user deal with unclean git repos
    checkGitStatusClean "${1}"

    pushd "${1}"
    # We want to unconditionally (re)configure the build, if a previous
    # build/ dir exists.
    #
    # ${JOBS:-} is expanded to nothing if JOBS isn't set above
    # which implies using the number of available hardware threads
    if [[ -d build/ ]]; then
        echo -e "\nAttempting to Uninstall prior installs of ${1} ...\n"
        sudo ninja uninstall -C build/
    fi
    echo -e "\nResetting ownership as a precaution ...\n"
    sudo chown -Rc ${USER}:${USER} *
    echo -e "\nConfiguring, building and installing ${1} ...\n"
    ( meson setup -Dbuildtype=debugoptimized --prefix="${INSTALL_PREFIX}" --wipe build/ || meson setup --prefix="${INSTALL_PREFIX}" build/ ) && \
    meson compile -C build/ ${JOBS:-} && \
    sudo meson install --no-rebuild -C build/
    # error out noisily if any of the build steps fail
    if [[ $? -gt 0 ]]; then
        failMsg "\n  Building ${1} failed!\n  '- Aborting!\n"
    fi
    popd
}

function buildAllDLangTools ()
{
    # We can do this because this invocation doesn't touch existing
    # bin dir/symlink
    mkdir -pv ${INSTALL_PREFIX}/bin
    echo -e "\nBuilding and installing moss-container and boulder...\n"
    for repo in moss-container boulder; do
        buildDLangTool "$repo"
    done
    echo -e "\nSuccessfully built and installed moss-container and boulder:\n"
    ls -lF ${INSTALL_PREFIX}/bin/{moss-container,boulder}
}

function buildRustTools ()
{
    local repo=moss
    echo -e "\nBuilding and installing moss and boulder...\n"
    isGitRepo "$repo" || \
        failMsg "${repo} does not appear to be a serpent tooling repo?"
    # Make the user deal with unclean git repos
    checkGitStatusClean "${repo}"

    pushd "${repo}"
    echo -e "\nResetting ownership as a precaution ...\n"
    sudo chown -Rc ${USER}:${USER} *
    echo -e "\nConfiguring, building and installing ${repo} ...\n"
    rm -v target/{debug,release}/{moss,boulder}
    # moss
    cargo build -p moss && \
      sudo install -Dm00755 target/debug/moss ${INSTALL_PREFIX}/bin/moss
    # error out noisily if any of the build steps fail
    if [[ $? -gt 0 ]]; then
        failMsg "\n  Building moss failed!\n  '- Aborting!\n"
    fi
    echo -e "\nSuccessfully built and installed moss:\n"
    ls -lF ${INSTALL_PREFIX}/bin/moss

    # boulder
    cargo build -p boulder && \
      sudo install -Dm00755 target/debug/moss ${INSTALL_PREFIX}/bin/boulder && \
      sudo mkdir -pv ${INSTALL_PREFIX}/share/boulder && \
      sudo cp -vr boulder/data ${INSTALL_PREFIX}/share/boulder/
    # error out noisily if any of the build steps fail
    if [[ $? -gt 0 ]]; then
        failMsg "\n  Building boulder failed!\n  '- Aborting!\n"
    fi
    echo -e "\nSuccessfully built and installed boulder:\n"
    ls -lF ${INSTALL_PREFIX}/bin/boulder
    ls -lF ${INSTALL_PREFIX}/share/boulder
    # done
    popd
}

function cleanTool ()
{
    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a serpent tooling repo?"

    pushd "${1}"
    if [[ -d build/ ]]; then
        echo -e "\nUninstalling ${1} ...\n"
        sudo ninja uninstall -C build/
        echo -e "\nResetting permissions for ${1} ...\n"
        sudo chown -Rc ${USER}:${USER} *
        echo -e "\nCleaning ${1}/build/ ...\n"
        meson compile --clean -C build/
        echo -e "\nDone.\n"
    else
        echo -e "\nCan't clean non-existing ${1}/build/ directory.\n"
    fi
    popd
}

function cleanAllDlangTools ()
{
    echo -e "\nRunning 'meson compile --clean' for all serpent repos...\n"
    for repo in boulder libstone moss-container; do
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
    checkGitStatusClean "${1}"
    checkoutRef ${1}

    pushd "${1}"
    git pull --rebase --recurse-submodules
    if [[ $? -eq 0 ]]; then
        echo -e "\nChecking ${1} SSH push URI...\n"
        local PUSH_URI="$(git remote get-url --push origin)"
        # Don't touch the push URI if the user has manually re-configured it
        # to a different SSH push URI than the default
        if [[ "${PUSH_URI}" =~ "git@github.com:" && ! "${PUSH_URI}" =~ "serpent-os" ]]; then
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
}

# Make it easier to do automated checkouts and builds of branches
# (useful for testing PRs spannning individual repo boundaries)
function checkoutRef ()
{
    local branch="${CORE_REPOS[${1}]}"
    echo -e "\nChecking out the ${1} ${branch} branch/tag"
    git -C "${1}" checkout "${branch}" || \
        failMsg "- failed to git checkout the ${branch} branch/tag for ${1}!"
    echo ""
}

function activateCommitHooks ()
{
    isGitRepo "${1}" || \
        failMsg "${1} does not appear to be a valid repo for adding git commit hooks? Aborting."

    pushd "${1}"
    local addHooks="./serpent-style/activate-git-hooks.sh"
    if [[ -x "${addHooks}" ]]; then
        ${addHooks}
    else
        ls -l "${addHooks}"
    fi
    echo -e "\nActive serpent-style git hooks in ${PWD}:\n"
    ls -l .git/hooks/ |grep 'serpent-style'
    echo ""
    popd
}

function updateRepo ()
{
    isGitRepo "${1}" && pullRepo "${1}" || cloneRepo "${1}"
    if [[ $? -eq 0 ]]; then
        activateCommitHooks "${1}"
    fi
}

function updateAllRepos ()
{
    echo -e "\nUpdating all serpent tooling repos to newest upstream version...\n"
    for repo in ${!CORE_REPOS[@]}; do
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
    checkGitStatusClean "${1}"

    pushd "${1}"

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
    echo -e "\nSuccessfully pushed newest local code to all serpent tooling repos.\n"
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
