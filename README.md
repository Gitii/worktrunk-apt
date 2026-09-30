# Worktrunk Debian packages

Builds [Worktrunk](https://worktrunk.dev/#install) `.deb` packages from its
published crates.io source using `cargo install --locked`. Builds run directly
in `ubuntu:24.04` and `ubuntu:26.04` Docker containers on GitHub-hosted
`ubuntu-24.04` runners, targeting **amd64**.

## Build a version

The version must already be published as the `worktrunk` crate on crates.io.
Packaging releases use the exact upstream release tag (for example, `v0.80.0`);
the publishing job verifies that this release exists in `max-sixty/worktrunk`.

- **Manual:** run **Actions → Build Debian packages → Run workflow** and enter
  a version or tag, such as `0.80.0` or `v0.80.0`. Download the packages and SHA-256
  checksums from the run's artifacts.
- **Tag:** push a matching version tag to this repository, such as `v0.80.0`.
  The workflow builds both packages, creates a release if needed, and attaches
  the packages and checksums.
- **Release:** publish a release in this repository with a matching version
  tag. The workflow attaches both packages and checksums to that release.

For example, version `v0.80.0` produces:

```text
worktrunk_0.80.0-1ubuntu24.04_amd64.deb
worktrunk_0.80.0-1ubuntu26.04_amd64.deb
```

Each package includes `/usr/bin/wt`, the upstream license, and runtime
dependencies detected on its target Ubuntu version. CI installs each package
with APT and checks `wt --version` and `wt --help` before uploading it.
Pull requests and pushes to `main` build `v0.80.0` on both Ubuntu targets as
build checks, without publishing a release.

## Install

Download the package for your Ubuntu version from
[Releases](https://github.com/Gitii/worktrunk-apt/releases), then install it:

```fish
sha256sum --check worktrunk_0.80.0-1ubuntu24.04_amd64.deb.sha256
sudo apt install ./worktrunk_0.80.0-1ubuntu24.04_amd64.deb
wt config shell install
```

Run `wt config shell install` as your own user to enable directory switching
in your shell, as recommended by the upstream install guide.

## Local build

On the matching Ubuntu release, install Rust with rustup and the build tools:

```fish
sudo apt install build-essential pkg-config dpkg-dev curl ca-certificates
rustup toolchain install stable --profile minimal
bash scripts/build-deb.sh v0.80.0 24.04 dist
```

The script requires the matching Ubuntu version and `amd64` architecture.
