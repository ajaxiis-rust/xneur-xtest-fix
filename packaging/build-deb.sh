#!/bin/bash
# Build a single self-contained .deb with patched xneur + gxneur.
#
#   ./packaging/build-deb.sh
#
# Result: dist/xneur-xtest_<version>_<arch>.deb
# Needs the build deps listed in README.md ("Сборка на Ubuntu 22.04").
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
WORK=${WORK:-/tmp/xneur-xtest-build}

BASE_COMMIT=5a964810103cf73783f8f8ebb2998be8a5b91eda
PKG=xneur-xtest
VER=0.21.0-xtest2
ARCH=$(dpkg --print-architecture)
MAINTAINER="ajaxiis-rust <ajaxiis-rust@users.noreply.github.com>"

SRC=$WORK/xneur-devel
ROOT=$WORK/root
OUT=$REPO/dist

say() { printf '\n==> %s\n' "$*"; }

rm -rf "$WORK" "$OUT"
mkdir -p "$SRC" "$ROOT" "$OUT"

say "upstream xneur-devel @ ${BASE_COMMIT:0:7}"
git -C "$SRC" init -q .
git -C "$SRC" remote add origin https://github.com/AndrewCrewKuznetsov/xneur-devel.git
git -C "$SRC" fetch -q --depth 1 origin "$BASE_COMMIT"
git -C "$SRC" checkout -q FETCH_HEAD
git -C "$SRC" apply "$REPO/xneur-0.21.0-xtest.patch"

# jammy ships /usr/include/enchant-2/*.h, the sources include <enchant/enchant.h>
say "enchant-2 header shim"
mkdir -p "$WORK/enchant-compat"
ln -sfn /usr/include/enchant-2 "$WORK/enchant-compat/enchant"
export CPPFLAGS="-I$WORK/enchant-compat"

build_tree() {
	local dir=$1
	shift
	cd "$SRC/$dir"
	# automake lists files the fork does not ship
	for f in INSTALL README TODO AUTHORS NEWS ChangeLog; do
		[ -e "$f" ] || touch "$f"
	done
	./autogen.sh "$@"
	make -j"$(nproc)"
	make install DESTDIR="$ROOT"
	cd "$SRC"
}

say "building xneur"
build_tree xneur --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
	--with-sound=no --without-xosd --without-keylogger

say "building gxneur"
build_tree gxneur --prefix=/usr --sysconfdir=/etc

say "cleaning staged tree"
rm -rf "$ROOT/usr/include" "$ROOT/usr/lib/pkgconfig"
# development symlinks: runtime resolves the versioned SONAMEs
rm -f "$ROOT/usr/lib/libxneur.so" "$ROOT/usr/lib/libxnconfig.so"
find "$ROOT" -type f \( -name '*.la' -o -name '*.a' \) -delete
find "$ROOT" -type f -name '*.so*' -exec strip --strip-unneeded {} +
strip --strip-unneeded "$ROOT/usr/bin/xneur" "$ROOT/usr/bin/gxneur"
# upstream installs everything 0775/0755; normalise for the archive
find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f -name '*.so*' -exec chmod 644 {} +
find "$ROOT" -type f ! -name '*.so*' ! -path "$ROOT/usr/bin/*" -exec chmod 644 {} +
chmod 755 "$ROOT/usr/bin/xneur" "$ROOT/usr/bin/gxneur"
find "$ROOT/usr/share/man" -type f -exec gzip -9n {} +

say "package metadata"
DOC=$ROOT/usr/share/doc/$PKG
install -d "$DOC"
install -m644 "$REPO/README.md" "$DOC/README.md"
install -m644 "$REPO/COPYING" "$DOC/COPYING"
sed "s/@VERSION@/$VER/g" "$HERE/debian/copyright" >"$DOC/copyright"
chmod 644 "$DOC/copyright"

install -Dm644 "$HERE/debian/gxneur-autostart.desktop" \
	"$ROOT/etc/xdg/autostart/gxneur.desktop"

D=$ROOT/DEBIAN
install -d "$D"
SIZE=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
sed -e "s/@PKG@/$PKG/g" -e "s/@VERSION@/$VER/g" -e "s/@ARCH@/$ARCH/g" \
	-e "s/@MAINTAINER@/$MAINTAINER/g" -e "s/@SIZE@/$SIZE/g" \
	"$HERE/debian/control" >"$D/control"
install -m755 "$HERE/debian/postinst" "$D/postinst"
install -m755 "$HERE/debian/prerm" "$D/prerm"
install -m644 "$HERE/debian/conffiles" "$D/conffiles"
install -m644 "$HERE/debian/triggers" "$D/triggers"
install -m644 "$HERE/debian/shlibs" "$D/shlibs"
sed "s/@VERSION@/$VER/g" "$HERE/debian/changelog" |
	gzip -9nc >"$DOC/changelog.Debian.gz"
chmod 644 "$DOC/changelog.Debian.gz"
(
	cd "$ROOT"
	find . -path ./DEBIAN -prune -o -type f -printf '%P\n' |
		grep -vxF -f <(sed 's|^/||' "$D/conffiles") |
		sort | xargs -d '\n' md5sum >"$D/md5sums"
)

say "dpkg-deb"
DEB=$OUT/${PKG}_${VER}_${ARCH}.deb
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB" >/dev/null
echo "$DEB"
dpkg-deb -I "$DEB" | sed -n '2,12p'
