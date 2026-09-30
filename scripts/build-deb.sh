#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
  printf 'Usage: %s <version-or-tag> <ubuntu-version> <output-directory>\n' "$0" >&2
  exit 1
fi

version=${1#v}
ubuntu=$2
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
  printf 'Invalid Worktrunk version: %s\n' "$1" >&2
  exit 1
fi
case "$ubuntu" in
  24.04|26.04) ;;
  *) printf 'Unsupported Ubuntu version: %s\n' "$ubuntu" >&2; exit 1 ;;
esac

# Never label a binary built on a different distribution as this Ubuntu target.
source /etc/os-release
if [[ "$ID" != ubuntu || "$VERSION_ID" != "$ubuntu" ]]; then
  printf 'Build on Ubuntu %s; current OS is %s %s.\n' "$ubuntu" "$ID" "$VERSION_ID" >&2
  exit 1
fi
if [[ $(dpkg --print-architecture) != amd64 ]]; then
  printf 'This workflow targets amd64.\n' >&2
  exit 1
fi

mkdir -p "$3"
output=$(realpath "$3")
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

# Use the exact crates.io source archive, including its lockfile and license.
curl --fail --location --retry 5 \
  "https://crates.io/api/v1/crates/worktrunk/$version/download" \
  --output "$build/source.crate"
tar -xzf "$build/source.crate" -C "$build"
crate="$build/worktrunk-$version"
cargo +stable install --path "$crate" --locked --root "$build/install"
"$build/install/bin/wt" --version

# Debian's '~' sorts prereleases before the corresponding stable version.
deb_version="${version/-/~}-1ubuntu${ubuntu}"
root="$build/package"
mkdir -p "$root/DEBIAN" "$root/usr/bin" "$root/usr/share/doc/worktrunk" "$build/debian"
install -m 755 "$build/install/bin/wt" "$root/usr/bin/wt"
strip "$root/usr/bin/wt"
install -m 644 "$crate/LICENSE" "$root/usr/share/doc/worktrunk/copyright"

cat > "$build/debian/control" <<EOF
Source: worktrunk
Section: devel
Priority: optional
Maintainer: Gitii <Gitii@users.noreply.github.com>

Package: worktrunk
Architecture: amd64
Description: Git worktree management for parallel AI agent workflows
EOF

# Resolve ELF dependencies against the target runner's Ubuntu package database.
cd "$build"
shlibs=$(dpkg-shlibdeps -O -e"$root/usr/bin/wt")
dependencies=${shlibs#shlibs:Depends=}
if [[ "$dependencies" == "$shlibs" || -z "$dependencies" ]]; then
  printf 'Could not determine runtime dependencies.\n' >&2
  exit 1
fi
installed_size=$(du -sk "$root/usr" | cut -f1)
cat > "$root/DEBIAN/control" <<EOF
Package: worktrunk
Version: $deb_version
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Gitii <Gitii@users.noreply.github.com>
Installed-Size: $installed_size
Depends: git, $dependencies
Homepage: https://worktrunk.dev
Description: Git worktree management for parallel AI agent workflows
 Worktrunk makes Git worktrees as easy as branches, with hooks and
 workflow automation for working on multiple branches in parallel.
 Built from the published Cargo crate for Ubuntu $ubuntu.
EOF

package="worktrunk_${deb_version}_amd64.deb"
dpkg-deb --root-owner-group --build "$root" "$output/$package"
dpkg-deb --info "$output/$package"
cd "$output"
sha256sum "$package" > "$package.sha256"
