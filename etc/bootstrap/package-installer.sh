#!/bin/bash
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
#
# Package all currently present build artefacts into the 'dist' directory
set -e

if [ -n "$1" ]; then
	echo "Usage: $0" >&2
	exit 1
fi

cd "$(dirname "$0")"/../..
base="$PWD"
PATH="$PWD/bin"
output="$base/installer"
mkdir -p "$output"

hosttriplet="$(bin/gcc --version)"
hosttriplet="${hosttriplet%%-gcc*}"

installer="$output/4diac-fbe-installer-v1"

if [ -f "$installer-$hosttriplet.tar.gz" ]; then
	echo "Installer $installer already exists. Edit $0 to create a new version."
	exit 1
fi

for dir in bin toolchain-*/bin; do
	cd "$base/${dir%bin}"
	triplet="${dir%/*}"
	triplet="${triplet#toolchain-}"

	case "$triplet" in
	*-w64-*)
		cp -a "$base/etc/bootstrap/install.sh" etc/bootstrap/install.sh
		exe=".exe"
		script=".cmd"
		archive="7za a -Tzip -mtc=off"
		ext=".zip";;
	bin)
		triplet="$hosttriplet"
		exe=""
		script=".sh"
		archive="tar czf"
		ext=".tar.gz";;
	*)
		cp -a "$base/etc/bootstrap/install.sh" etc/bootstrap/install.sh
		exe=""
		script=".sh"
		archive="tar czf"
		ext=.tar.gz;;
	esac
	file="$installer-$triplet$ext"
	$archive "$file" bin/busybox$exe bin/lzip$exe bin/curl$exe etc/bootstrap/install.sh
	hash="$(sha256sum "$file")"
	sed -i -e "s/installer='.*'/installer='${file##*/}'/;s/\\(\\($triplet) \\|\\$\\)installerhash\\)='[0-9a-f]\\{64\\}'/\\1='${hash%% *}'/" $base/etc/install$script
done
