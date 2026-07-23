#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/utils.sh"

DFILE="$MODDIR/disabled_by_action"

if [ -z "$(get_mounts)" ]; then
	rm -f "$DFILE"
	if mount_nosleep; then
		echo "* Enabled successfully"
		cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
	else
		echo "* Failed"
	fi
else
	touch "$DFILE"
	umount_all
	echo "* Disabled"
	ch_desc "⛔ Disabled by action"
fi

if [ -f "$MODDIR/detach" ]; then
	echo ""
	echo "[*] Running Zygisk Play Store Detach..."
	
	# Ensure the app is registered in Zygisk Detach
	if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
		"$MODDIR/detach" add "$PKG_NAME" >/dev/null 2>&1
	else
		mkdir -p /data/adb/zygisk-detach
		echo "$PKG_NAME" > "$MODDIR/temp_detach.txt"
		"$MODDIR/detach" serialize "$MODDIR/temp_detach.txt" "/data/adb/zygisk-detach/detach.bin" >/dev/null 2>&1
		rm -f "$MODDIR/temp_detach.txt"
	fi
	
	# Force stop Google Play Store to apply the detach immediately
	am force-stop com.android.vending
	echo "[*] Play Store force-stopped. Detached successfully!"
fi

echo ""
get_mounts
