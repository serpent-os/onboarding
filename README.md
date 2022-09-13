## Description

Onboarding documentation and convenience scripts for cloning/building/pulling/pushing the Serpent OS tooling.

For a general overview of the goals of Serpent OS and how to get in touch, see our [website](https://serpentos.com).

## Onboarding

Serpent OS tooling is written primarily in [Dlang](https://dlang.org/).

### Prerequisites

We use:

- [`git`](https://git-scm.com/) to manage development.
- [`meson`](https://mesonbuild.com/) (with [`dub`](https://dub.pm/) as a fallback) and [`ldc2`](https://wiki.dlang.org/LDC) to build our binaries. 
- [`dfmt`](https://github.com/dlang-community/dfmt) to format our code consistently. Consult the [`dfmt` README](https://github.com/dlang-community/dfmt#installation) for how to build it with LDC. Our scripts assume that `dfmt` is available in `$PATH`.
- the python module `codespell` for spell checking. Install it from your distribution's package manager.

For convenience, we maintain a `check-prereqs.sh` script, which will check for all necessary binaries, runtime libraries and development headers and report missing prerequisites.

#### Dlang Toolchain installation

The currently recommended way to install the Dlang toolchain is to use the official install script:

    curl -fsS https://dlang.org/install.sh | bash -s ldc

Remember to source the appropriate environment initialisation script from your preferred shell's user config file.

We tend to follow the newest upstream version of LDC quite closely.

### Repo structure

We use a flat repository structure where all Dlang `meson`-controlled subprojects are expected to be checked out concurrently.

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

Note that the build process can require up to 12 GiB of Resident memory, so a system with **16 GiB of RAM is recommended** and it may be necessary to turn on zram (or zswap) to make `boulder` compile successfully.

### Serpent tooling build order

To get started packaging with the current pre-alpha quality serpent tooling, the following binaries need to be built in the order listed below:

- [`moss`](https://github.com/serpent-os/moss) (our system software management tool)
- [`moss-container`](https://github.com/serpent-os/moss-container) (our lightweight container tool)
- [`boulder`](https://github.com/serpent-os/boulder) (our system software build tool)

The `./update.sh` script updates, builds and installs the serpent tooling to `/usr` in the order listed above.

## Introduction to the Serpent OS packaging process

    Build Recipe (stone.yml) -> [boulder build] -> (package.stone + metadata) -> [moss .stone collection] -> moss install package

### Creating a stone.yml recipe template

The high level flow is that packagers start by creating a `stone.yml` build recipe using `boulder new URI-to-tarball-they-wish-to-package`. This outputs a bare bones `stone.yml` recipe that will need fleshing out with summary, description, patches, build steps etc.

### Building a stone.yml recipe into a binary package.stone

To actually build a Serpent OS format .stone binary package, packagers invoke `sudo boulder build stone.yml`. This will parse the `stone.yml` build recipe and execute the various setup, build, install etc. steps specified in the recipe and discover + add relevant metadata, dependencies etc. to the finished `somepackage.stone` binary build artefact. The process will also produce a moss-readable binary format build manifest named `manifest.bin` plus a human readable `manifest.json` file containing essentially the same metadata as `manifest.bin` but only used for `git diff` purposes.

### Adding package.stone to a moss .stone collection

Binary moss .stone packages are kept in moss .stone collections, which each have a `stone.index` file containing the metadata from all the .stone packages in the collection. Thus, to be able to install a newly built package, it will need to be moved to a known collection, which then needs to have its `stone.index` file updated to include the metadata from the newly added .stone.

Once the collection index has been updated, moss will be able to install the package that was just added to the collection.

The following section details how to get started with this process.

## Initial moss setup for running a Serpent OS systemd-nspawn container

To be able to actually use moss, its various databases need to be initialised inside a clean folder, which will function as a root directory for a systemd-nspawn container later on.

This can be accomplished with the following set of commands:

    mkdir destdir
    # add a moss .stone collection from which to install packages
    moss -D destdir ar protosnek https://dev.serpentos.com/protosnek/x86_64/stone.index
    # list available packages/.stones in the configured moss .stone collection
    moss la -D destdir

Install a useful (if minimal) set of .stones:

    moss it -D destdir nss systemd coreutils util-linux dash bash which dbus dbus-broker nano

Boot a systemd-nspawn container with the installed minimal Serpent OS system:

    sudo systemd-nspawn -D destdir -b

To stop and exit the systemd-nspawn container, issue the following command:

    systemctl poweroff

**NB**: Do NOT install `moss` to or within the destdir root used for the systemd-nspawn container, as this version downloaded from the protosnek collection is not compatible with the one used outside the container at this point in time.

### Local moss collection support

Moss and Boulder now support profiles that include multiple moss collections with priorities (higher priority overrides lower priority). Things are still a bit rough around the edges, but the following instructions should get you going with packaging in a local collection and using the .stones you put there as dependencies for subsequent builds:

    # create /var/cache/boulder/collections/local-x86_64
    sudo mkdir -pv /var/cache/boulder/collections/local-x86_64
    # ensure your user has write access to the local moss .stone collection
    sudo chown -Rc ${USER}:${USER} /var/cache/boulder/collections/local-x86-64
    # dowload/prepare a collection of stones there, then create a moss stone.index file
    moss idx /var/cache/boulder/collections/local-x86_64
    # newest boulder ships with a profile configuration that enables using the
    # local collection for dependencies, so no need to add it before building
    sudo boulder build stone.yml -p local-x86_64

## Support

Please refer to the [website](https://serpentos.com) for instructions on how to get in touch with the Serpent OS developers.

## Contributing

Please get in touch with the [Serpent OS developers](https://serpentos.com/team) before contributing pull requests.

We're a friendly bunch and will likely welcome your contributions.

## License

Serpent OS is licensed under the Zlib license.
