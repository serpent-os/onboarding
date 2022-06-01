## Description

Onboarding documentation and convenience scripts for cloning/building/pulling/pushing the Serpent OS tooling.

For a general overview of the goals of Serpent OS and how to get in touch, see our [website](https://serpentos.com).

## Onboarding

Serpent OS tooling is written primarily in [Dlang](https://dlang.org/).

### Prerequisites

We use [`meson`](https://mesonbuild.com/) (with [`dub`](https://dub.pm/) as a fallback) and [`ldc2`](https://wiki.dlang.org/LDC) to build our binaries. 

We use [`git`](https://git-scm.com/) to manage development.

We use [`dfmt`](https://github.com/dlang-community/dfmt) to format our code consistently. Consult the [`dfmt` README](https://github.com/dlang-community/dfmt#installation) for how to build it with ldc. Our scripts assume that `dfmt` is available somewhere in `$PATH`.

We use the python module `codespell` for spell checking. Install it from your distribution's package manager.

#### Dlang Toolchain installation

The currently recommended way to install the Dlang toolchain is to use the official install script:

    curl -fsS https://dlang.org/install.sh | bash -s ldc

Remember to source the appropriate environment initialisation script from your preferred shell's user config file.

We tend to follow the newest upstream version of ldc quite closely.

### Repo structure

We use a flat repository structure where all Dlang `meson`-controlled subprojects are expected to be checked out concurrently.

This forces a "lockstep" development methodology, which means that whatever is currently checked out in each subproject is what any given binary will be built against.

This also implies that all subprojects will need to be kept in sync with the features that are being worked on (preferrably using identical topic branch names).

The only place we use "full" git submodules is in `moss-vendor`.

### Example

Here, all relevant Serpent OS subprojects will be checked out under `~/repos/serpent-os/`

```
# Initial setup
mkdir ~/repos/serpent-os/
cd ~/repos/serpent-os/

git clone https://gitlab.com/serpent-os/core/onboarding/
onboarding/clone-all.sh
onboarding/build-all.sh
```

### Serpent tooling build order

To get started packaging with the current pre-alpha quality serpent tooling, the following serpent tools need to be built in the order listed below:

- [`moss`](https://gitlab.com/serpent-os/core/moss) (our system software management tool)
- [`moss-container`](https://gitlab.com/serpent-os/core/moss-container) (our lightweight container tool)
- [`boulder`](https://gitlab.com/serpent-os/core/boulder) (our system software build tool)

The `build-all.sh` script builds the tools in the order listed above.

## Support

Please reference the website for instructions on how to get in touch with the Serpent OS developers.

## Contributing

Please get in touch with the Serpent OS developers before contributing MRs.

We're a friendly bunch and will likely welcome your contributions.

## License

Serpent OS is licensed under the Zlib license.
