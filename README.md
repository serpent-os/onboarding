## Description

Shared scripts and onboarding documentation for the rest of the Serpent OS tooling.

For a general overview of the goals of Serpent OS and how to get in touch, see our [website](https://serpentos.com).

## Onboarding

Serpent OS tooling is written primarily in Dlang.

### Prerequisites

We use `meson` (with `dub` as a fallback) and `ldc2` to build our binaries. We use `git` for development.

### Repo structure

We use a flat repository structure where all Dlang submodules are expected to be checked out concurrently.

This forces a "lockstep" development methodology, which means that whatever is currently checked out in each submodule is what any given binary will be built against.

This also implies that all submodules will need to be kept in sync with the features that are being worked on (preferrably using identical topic branch names).

### Example

Here, all relevant Serpent OS modules will be checked out under `~/repos/serpent-os/`

```
# Initial setup
mkdir ~/repos/serpent-os/
cd ~/repos/serpent-os/

# for 3rd party contributors without commit access
git clone https://gitlab.com/serpent-os/core/common.git
# for Serpent OS team members with commit access
# git clone git@gitlab.com:serpent-os/core/common.git 

common/git-clone.sh --https # drop the --https argument if you use ssh
```

## Support

Please reference the website for instructions on how to get in touch with the Serpent OS developers.

## Contributing

Please get in touch with the Serpent OS developers before contributing MRs.

We're a friendly bunch and will likely welcome your contributions.

## License

Serpent OS is licensed under the Zlib license.
