#!/bin/sh
#********************************************************************************
# Copyright (c) 2018, 2024 OFFIS e.V.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
# 
# Contributors:
#    Jörg Walter - initial implementation
# *******************************************************************************/
set -e

if [ -x bin/sh -a "$1" != "-u" ]; then
	echo "Toolchain already installed. Use '$0 -u' to update."
	exit 0
fi

die() { echo "$*" >&2; exit 1; }

host="$(uname -s)"
arch="$(uname -m)"
[ "$arch" != "arm64" ] || arch="aarch64"

baseurl="https://sourceforge.net/projects/fordiac/files/4diac-fbe"
triplet="$arch-apple-darwin20.2"
file="$host-toolchain-$triplet.tar.gz"

release='2024-08'
hash='a733e48569d35567d36c7adca06a5ca0d4f10269da269ed5aa5914103c16ad94'


sha256_check() {
	local download="$1" hash="$2"
	if ! type shasum > /dev/null; then
		echo "WARNING: sha256sum not found, not verifying archives."
	elif [ "$(shasum -a 256 < "$download")" != "$hash  -" ]; then
		mv "$download" "$download.broken"
		die "SHA256 checksum for $download doesn't match expected value!"
	fi
}
fetch_file_authenticated() {
	download="$1"
	url="$2"
	hash="$3"

	if [ ! -f "$download" ]; then
		echo "Downloading $url..."
		if type curl >/dev/null && curl --location --disable --insecure -o "$download" "$url"; then
			: # obvious tool
		elif type wget >/dev/null && wget --no-check-certificate -O "$download" "$url"; then
			: # obvious tool
		elif type wget2 >/dev/null && wget2 --no-check-certificate -O "$download" "$url"; then
			: # obvious tool
		elif type python >/dev/null && python - "$url" "$download" << 'EOF'; then
import sys
try: from urllib.request import urlretrieve
except: from urllib import urlretrieve
urlretrieve(sys.argv[1], sys.argv[2])
EOF
			: # works for python2 and python3
		elif type GET >/dev/null && GET "$url" > "$download"; then
			: # libwww-perl
		elif type perl >/dev/null && perl 'use LWP::Simple; exit(getstore($ARGV[0], $ARGV[1])-200)' "$url" "$download"; then
			: # same, just in case the command line utilities are not installed
		elif type fetch >/dev/null && fetch --no-verify-peer -o "$download" "$url"; then
			: # FreeBSD
		else
			die "Need a download program with SSL/TLS support: curl, wget, python2, python3, or libwww-perl."
		fi
	fi

	sha256_check "$download" "$hash"
}

fetch_file_authenticated "$file" "$baseurl/release-$release/$file/download" "$hash"
[ -f "$file" ] || die "ERROR: Could not download $file. Please download it manually and put it into $PWD"

gzip -d < "$file" | tar x
mkdir -p ".cache/sha256-$hash"
mv "$file" ".cache/sha256-$hash/$file"
rm -f *-toolchain-*.zip *-toolchain-*.tar.gz

"$PWD"/bin/busybox --install "$PWD/bin"

# Install SDK / message user about SDK installation
clang-toolchain/bin/$arch-apple-darwin*-clang --version

echo "Installation complete. Run ./install-crosscompiler.sh to download additional cross-compiling toolchains."
./install-crosscompiler.sh || true
