#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/config"

rm -f "/data/adb/bizarre/${MODDIR##*/}.apk"
rmdir "/data/adb/bizarre"

rm -f "/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
