## Current onboarding documentation

The current user-facing Serpent OS tooling onboarding documentation lives [here](https://github.com/serpent-os/moss).

## Description

Legacy Onboarding documentation and convenience scripts for cloning/building/pulling/pushing the Serpent OS DLang tooling.

For a general overview of the goals of Serpent OS and how to get in touch, see our [website](https://serpentos.com).

## Onboarding

Serpent OS tooling is being redesigned in [Rust](https://rustlang.org).

The legacy PoC tooling was written primarily in [Dlang](https://dlang.org/).

### Prerequisites

We use:

- [`git`](https://git-scm.com/) to manage development.
- [`cargo`](https://doc.rust-lang.org/cargo/index.html) and [`rustc`](https://doc.rust-lang.org/rustc/index.html) to build our Rust binaries.
- [`rustfmt`](https://rust-lang.github.io/rustfmt/) to format our Rust code consistently.
- [`meson`](https://mesonbuild.com/) (with [`dub`](https://dub.pm/) as a fallback) and [`ldc2`](https://wiki.dlang.org/LDC) to build our legacy DLang binaries.
- [`dfmt`](https://github.com/dlang-community/dfmt) to format our legacy DLang code consistently. Consult the [`dfmt` README](https://github.com/dlang-community/dfmt#installation) for how to build it with LDC. Our scripts assume that `dfmt` is available in `$PATH`.
- the python module `codespell` for spell checking. Install it from your distribution's package manager.
- the [`go-task`](https://github.com/go-task/task/releases) Go application to maintain frequently executed job compositions without having to clutter a repository with Makefiles or the like.

For convenience, we maintain a `check-prereqs.sh` script, which will check for all necessary binaries, runtime libraries and development headers and report missing prerequisites.

#### Rust Toolchain installation

Most Linux distributions ship recent versions of both `cargo`, `rustc` and `rustfmt`. Consult your distribution's documentation for more information on how to install the relevant packages.

#### LDC Dlang Toolchain installation (DMD not supported)

_The latest supported ldc version is **1.32.2**_.

The currently recommended way to install the Dlang toolchain is to use the official install script:

    curl -fsS https://dlang.org/install.sh | bash -s ldc-1.32.2

**NB:** Remember to _source_ ('activate') the appropriate environment initialisation script from your preferred shell's user config file.

#### LDC Dlang Toolchain update

One of our users kindly shared their experience updating an already installed LDC instance. [Read more here](https://forums.serpentos.com/d/22-how-to-test-moss/4)

### Repo structure

Our Rust tooling repository is structured with multiple workspaces, so only a single repo needs to be cloned, which makes development more convenient.

For our legacy DLang tooling, we use a flat repository structure where all Dlang `meson`-controlled subprojects are expected to be checked out concurrently.

This forces a "lockstep" development methodology, which means that whatever is currently checked out in each subproject is what any given binary will be built against.

This also implies that all subprojects will need to be kept in sync with the features that are being worked on (preferably using identical topic branch names).

The only place we use "full" git submodules is in `moss-vendor`.

#### Getting and building the serpent tooling

Here, all relevant Serpent OS subprojects will be checked out under `~/repos/serpent-os/`

```
# Initial setup
mkdir -pv ~/repos/serpent-os/
cd ~/repos/serpent-os/

curl https://raw.githubusercontent.com/serpent-os/onboarding/main/init.sh |bash
```

#### A note on RAM requirements

A system with at least **8 GiB of RAM is recommended** and compressed swap (zram or zswap) might make the build experience smoother whilst a webbrowser is open.

In addition, the onboarding build scripts will attempt to tune the amount of `boulder` parallel build jobs to fit with the available memory on the system.

### Legacy serpent DLang tooling build order

To get started packaging with the legacy pre-alpha quality serpent tooling, the following binaries need to be built in the order listed below:

- [`moss-container`](https://github.com/serpent-os/moss-container) (our lightweight container tool)
- [`boulder`](https://github.com/serpent-os/boulder) (our system software build tool)

The `./update.sh` script updates, builds and installs the serpent tooling to `/usr` in the order listed above. It also builds and installs the new Rust-based moss binary.

## Short introduction to the Serpent OS packaging workflow

- Create new recipe: `boulder new https://some.uri/to-a-package-version.tar.gz` -> outputs new `stone.yml` recipe
- Edit new recipe: `nano -w stone.yml`
- Build new recipe: `boulder build stone.yml -p local-x86_64` -> outputs `package.stone` + metadata (`manifest.*` build manifests) in current directory
- Copy new package.stone to the local binary moss repo and include it in index: `cp package.stone /var/cache/boulder/repos/local-x86_64/ && moss index /var/cache/boulder/repos/local-x86_64/`
- Add local repo  to repos searched by moss: `moss repo add local-x86_64 file:///var/cache/boulder/repos/local-x86_64/stone.index -p 10`
- Install package from local collection: `moss install package`

### Creating a stone.yml recipe template

The high level flow is that packagers start by creating a `stone.yml` build recipe using `boulder new URI-to-tarball-they-wish-to-package`. This outputs a bare bones `stone.yml` recipe that will need fleshing out with summary, description, patches, build steps etc.

### Building a stone.yml recipe into a binary package.stone

To actually build a Serpent OS format .stone binary package, packagers invoke `sudo boulder build stone.yml`. This will parse the `stone.yml` build recipe and execute the various setup, build, install etc. steps specified in the recipe and discover + add relevant metadata, dependencies etc. to the finished `somepackage.stone` binary build artefact. The process will also produce a moss-readable binary format build manifest named `manifest.$arch.bin` plus a human readable `manifest.jsonc` file containing essentially the same metadata as the binary manifest, but only used for `git diff` purposes.

### Adding package.stone to a moss repository

Binary moss .stone packages are kept in moss repositories, which each have a `stone.index` file containing the metadata from all the .stone packages in the repo. Thus, to be able to install a newly built package, it will need to be moved to a known moss repo, which then needs to have its `stone.index` file updated to include the metadata from the newly added .stone.

Once the moss repo index has been updated, moss will be able to install the package that was just added to the moss repo.

The following section details how to get started with this process.

## Initial moss setup for running a Serpent OS systemd-nspawn container

To be able to actually use moss, its various databases need to be initialised inside a clean folder, which will function as a root directory for a systemd-nspawn container later on.

This can be accomplished by executing:

    cd img-tests/
    ./create-sosroot.sh

which will install a suitable set of packages for use in a systemd-nspawn container.

Boot a systemd-nspawn container with the installed minimal Serpent OS system:

    sudo systemd-nspawn --bind=/var/cache/boulder/ -D ./sosroot/ -b

To stop and exit the systemd-nspawn container, issue the following command from within the container:

    poweroff

If the container locks up or stops responding, you might be able to use `machinectl` to stop it from outside the container:

    sudo machinectl poweroff sosroot

### Local moss repo support

Moss and Boulder now support profiles that include multiple moss repos with priorities (higher priority overrides lower priority). Things are still a bit rough around the edges, but the following instructions should get you going with packaging in a local collection and using the .stones you put there as dependencies for subsequent builds:

    # create /var/cache/boulder/repos/local-x86_64
    sudo mkdir -pv /var/cache/boulder/repos/local-x86_64
    # ensure your user has write access to the local moss repo
    sudo chown -Rc ${USER}:${USER} /var/cache/boulder/repos/local-x86_64
    # dowload/prepare a set of stones there (can be empty initially),
    # then create a moss stone.index file
    moss -D sosroot/ index /var/cache/boulder/repos/local-x86_64/
    # add the new collection to the list of known collections to moss (highest priority so far)
    moss -D sosroot/ repo add local-x86_64 file:///var/cache/boulder/repos/local-x86_64/stone.index -p10
    # Ask moss to list the available .stones (including now the ones in the local colleciton)
    moss -D sosroot/ list available
    # newest boulder ships with a profile configuration that enables using the
    # local repo for dependencies, so no need to add it before building
    sudo boulder build stone.yml -p local-x86_64

**NB**: Currently, whenever a new .stone is added to a local repo, the local repo index needs to be updated with `moss index (...)`.

## Support

Please refer to the [website](https://serpentos.com) for instructions on how to get in touch with the Serpent OS developers.

## Contributing

Please get in touch with the [Serpent OS developers](https://serpentos.com/team) before contributing pull requests.

We're a friendly bunch and will likely welcome your contributions.

## License

Serpent OS is licensed under the MPL-2.0 license. Legacy tooling is licensed under the Zlib license.
