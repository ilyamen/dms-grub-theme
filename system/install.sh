#!/bin/sh
# Install or remove the system side of the plugin: the helper that renders the
# theme into /boot/grub/themes/dms, its polkit action and the fonts it uses.
#   install.sh [install|uninstall]    as root; PREFIX defaults to /usr/local
set -eu

PREFIX=${PREFIX:-/usr/local}
LIBEXECDIR=$PREFIX/libexec
DATADIR=$PREFIX/share/dms-grub-theme
POLICY=/usr/share/polkit-1/actions/io.github.ilyamen.dms-grub-theme.policy
THEME_DIR=/boot/grub/themes/dms
CFG=/etc/default/grub.d/90-dms-grub-theme.cfg
here=$(dirname "$(readlink -f "$0")")

case ${1:-install} in
install)
    install -Dm755 "$here/dms-grub-theme" "$LIBEXECDIR/dms-grub-theme"
    sed "s|@LIBEXECDIR@|$LIBEXECDIR|g" "$here/dms-grub-theme.policy.in" | install -Dm644 /dev/stdin "$POLICY"
    "$LIBEXECDIR/dms-grub-theme" fonts
    ;;
uninstall)
    rm -rf "$THEME_DIR" "$DATADIR"
    rm -f "$CFG" "$LIBEXECDIR/dms-grub-theme" "$POLICY"
    if command -v update-grub >/dev/null; then
        update-grub
    fi
    ;;
*)
    echo "usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
