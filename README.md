## Description

Onboarding documentation and initial clone script for the Serpent OS tooling.

For a general overview of the goals of Serpent OS and how to get in touch, see our [website](https://serpentos.com).

## Onboarding

Serpent OS tooling is written primarily in [Dlang](https://dlang.org/).

### Prerequisites

We use [`meson`](https://mesonbuild.com/) (with [`dub`](https://dub.pm/) as a fallback) and [`ldc2`](https://wiki.dlang.org/LDC) to build our binaries. We use [`git`](https://git-scm.com/) to manage development.

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

curl https://gitlab.com/serpent-os/core/onboarding/-/raw/main/git-clone.sh |bash
```

## Support

Please reference the website for instructions on how to get in touch with the Serpent OS developers.

## Contributing

Please get in touch with the Serpent OS developers before contributing MRs.

We're a friendly bunch and will likely welcome your contributions.

## License

Serpent OS is licensed under the Zlib license.
