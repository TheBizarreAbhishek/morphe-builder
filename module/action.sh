#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/utils.sh"

echo "========================================="
echo "        M O R P H E   A C T I O N        "
echo "========================================="
echo "  * Press [Volume Up]   -> Toggle Mount"
echo "  * Press [Volume Down] -> Detach PlayStore"
echo "  * No press (5s)       -> Default (Toggle)"
echo "========================================="
echo "Waiting for volume key press..."

KEY=$(timeout 5 getevent -lc 1 2>/dev/null | grep -oE "KEY_VOLUMEUP|KEY_VOLUMEDOWN" | head -n 1)

if [ "$KEY" = "KEY_VOLUMEDOWN" ]; then
	echo "[+] Selected: PlayStore Detach"
	if [ -f "$MODDIR/detach" ]; then
		echo "[+] Running Zygisk Play Store Detach..."
		
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
		echo "[+] Play Store force-stopped. Detached successfully!"
	else
		echo "[-] Detach failed: Zygisk Detach binaries are missing."
	fi
else
	echo "[+] Selected: Toggle Mount"
	DFILE="$MODDIR/disabled_by_action"
	if [ -z "$(get_mounts)" ]; then
		rm -f "$DFILE"
		if mount_nosleep; then
			echo "[+] Enabled successfully"
			cp -f "$MODDIR/module.prop.orig" "$MODDIR/module.prop"
		else
			echo "[-] Failed to mount"
		fi
		echo ""
		get_mounts
	else
		touch "$DFILE"
		umount_all
		echo "[+] Disabled successfully"
		ch_desc "⛔ Disabled by action"
	fi
fi
