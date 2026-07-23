#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/utils.sh"

detach_playstore() {
	local sqlite_cmd=""
	if command -v sqlite3 >/dev/null 2>&1; then
		sqlite_cmd="sqlite3"
	elif [ -f "/data/adb/bizarre/sqlite3" ]; then
		sqlite_cmd="/data/adb/bizarre/sqlite3"
	fi

	if [ "$sqlite_cmd" ]; then
		am force-stop com.android.vending
		if [ -f "/data/data/com.android.vending/databases/localappstate.db" ]; then
			"$sqlite_cmd" /data/data/com.android.vending/databases/localappstate.db "DELETE FROM package_state WHERE package_name = '$PKG_NAME';" >/dev/null 2>&1
		fi
		if [ -f "/data/data/com.android.vending/databases/library.db" ]; then
			"$sqlite_cmd" /data/data/com.android.vending/databases/library.db "DELETE FROM ownership WHERE doc_id = '$PKG_NAME';" >/dev/null 2>&1
			"$sqlite_cmd" /data/data/com.android.vending/databases/library.db "DELETE FROM ownership WHERE package_name = '$PKG_NAME';" >/dev/null 2>&1
		fi
		am force-stop com.android.vending
	fi
}

monitor_app_launch() {
	local fail_count=0
	for i in {1..12}; do
		sleep 5
		if logcat -d | tail -n 100 | grep -F "FATAL EXCEPTION" | grep -Fq "$PKG_NAME"; then
			fail_count=$((fail_count + 1))
		fi
		if [ "$fail_count" -ge 2 ]; then
			umount_all
			ch_desc_err "Safe Mode: Mount disabled due to startup crashes"
			return 1
		fi
	done
}

run() {
	until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
	until [ -d "/sdcard/Android" ]; do sleep 1; done

	while
		BASEPATH=$(get_basepath)
		SVCL=$?
		[ $SVCL = 20 ]
	do sleep 2; done

	if [ $SVCL != 0 ]; then
		ch_desc_err "App not installed"
		return
	fi
	sleep 4

	if mount_rv "$BASEPATH"; then
		detach_playstore
		monitor_app_launch &
	fi
}

if [ ! -f "$MODDIR/disabled_by_action" ]; then
	run
fi
