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
	
	# Check if sqlite3 is available
	SQLITE_PATH=""
	if command -v sqlite3 >/dev/null 2>&1; then
		SQLITE_PATH="sqlite3"
	elif [ -f "/data/adb/bizarre/sqlite3" ]; then
		SQLITE_PATH="/data/adb/bizarre/sqlite3"
	fi
	
	if [ -z "$SQLITE_PATH" ]; then
		echo "[!] sqlite3 utility not found!"
		echo "[+] Attempting to download static sqlite3 binary..."
		
		# Detect architecture
		ARCH=$(getprop ro.product.cpu.abi)
		echo "    * Device ABI: $ARCH"
		
		# Download URL for static sqlite3 for Android
		URL=""
		if [ "$ARCH" = "arm64-v8a" ] || [ "$ARCH" = "armeabi-v7a" ]; then
			URL="https://github.com/Magisk-Modules-Alt-Repo/sqlite3-universal-binaries/raw/main/system/xbin/sqlite3"
		elif [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "x86" ]; then
			URL="https://github.com/Magisk-Modules-Alt-Repo/sqlite3-universal-binaries/raw/main/system/xbin/sqlite3"
		fi
		
		if [ "$URL" ]; then
			mkdir -p /data/adb/bizarre
			if curl -L -k -s -o /data/adb/bizarre/sqlite3 "$URL" || wget -q -O /data/adb/bizarre/sqlite3 "$URL"; then
				chmod 755 /data/adb/bizarre/sqlite3
				SQLITE_PATH="/data/adb/bizarre/sqlite3"
				echo "[+] sqlite3 installed successfully to /data/adb/bizarre/sqlite3!"
			else
				echo "[-] Download failed. Please check internet connection."
			fi
		else
			echo "[-] Architecture $ARCH not supported for auto-download."
		fi
	fi
	
	if [ "$SQLITE_PATH" ]; then
		echo "[+] Detaching $PKG_NAME from Google Play Store..."
		am force-stop com.android.vending
		if [ -f "/data/data/com.android.vending/databases/localappstate.db" ]; then
			"$SQLITE_PATH" /data/data/com.android.vending/databases/localappstate.db "DELETE FROM package_state WHERE package_name = '$PKG_NAME';" >/dev/null 2>&1
		fi
		if [ -f "/data/data/com.android.vending/databases/library.db" ]; then
			"$SQLITE_PATH" /data/data/com.android.vending/databases/library.db "DELETE FROM ownership WHERE doc_id = '$PKG_NAME';" >/dev/null 2>&1
			"$SQLITE_PATH" /data/data/com.android.vending/databases/library.db "DELETE FROM ownership WHERE package_name = '$PKG_NAME';" >/dev/null 2>&1
		fi
		am force-stop com.android.vending
		echo "[+] Detach completed successfully!"
	else
		echo "[-] Detach failed because sqlite3 is missing."
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
