#!/system/bin/sh
MODDIR=$MODPATH
. "$MODPATH/utils.sh"

ui_print "========================================="
ui_print "   B I Z A R R E   I N S T A L L E R     "
ui_print "========================================="
ui_print "  * Project: Morphe Builder"
ui_print "  * Author: Abhishek Babu"
ui_print "========================================="
ui_print ""

ui_print "[+] Verification: Checking device architecture..."
if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
	abort "[-] ERROR: Wrong arch! Your device: $ARCH, Module: $MODULE_ARCH"
fi

if [ "$ARCH" = "arm" ]; then
	ARCH_LIB=armeabi-v7a
elif [ "$ARCH" = "arm64" ]; then
	ARCH_LIB=arm64-v8a
elif [ "$ARCH" = "x86" ]; then
	ARCH_LIB=x86
elif [ "$ARCH" = "x64" ]; then
	ARCH_LIB=x86_64
else abort "[-] ERROR: Unreachable architecture: ${ARCH}"; fi

set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

ui_print "[+] Verification: Cleaning up existing mounts..."
umount_all

ui_print "[+] Verification: Checking $PKG_NAME installation status..."
if OP=$(dumpsys package "$PKG_NAME") && [ "$OP" ]; then
	if echo "$OP" | grep -m1 pkgFlags | grep -Fq UPDATED_SYSTEM_APP; then
		ui_print "    * Found updated system app. Reverting updates..."
		pmex uninstall-system-updates "$PKG_NAME" >/dev/null 2>&1
	fi
else
	if pmex install-existing "$PKG_NAME" >/dev/null 2>&1; then
		ui_print "    * Found hidden package. Enabling and reverting updates..."
		pmex uninstall-system-updates "$PKG_NAME" >/dev/null 2>&1
	fi
fi

INS=true
if BASEPATH=$(get_basepath); then
	if [ "${BASEPATH:1:4}" != data ]; then
		ui_print "[!] Detected $PKG_NAME as a factory system app"
		SCNM="/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
		mkdir -p /data/adb/post-fs-data.d
		echo "mount -t tmpfs none $BASEPATH" >"$SCNM"
		chmod +x "$SCNM"
		ui_print "    * Created post-fs-data early mount hide script."
		ui_print ""
		ui_print "[!] Reboot your device and re-flash this module!"
		abort
	fi

	VERSION=$(get_app_version)
	if [ "$VERSION" ] && [ "$VERSION" = "$PKG_VER" ]; then
		ui_print "[+] Status: $PKG_NAME is up-to-date ($VERSION)"
		INS=false
	else
		if [ "$VERSION" ]; then
			ui_print "[!] Alert: Version mismatch detected!"
			ui_print "    * Installed version: $VERSION"
			ui_print "    * Required version:  $PKG_VER"
			ui_print "[+] Action: Reverting/Uninstalling old version of $PKG_NAME..."
			if OP=$(dumpsys package "$PKG_NAME") && echo "$OP" | grep -m1 pkgFlags | grep -Fq SYSTEM; then
				ui_print "    * Reverting system updates..."
				pmex uninstall-system-updates "$PKG_NAME" >/dev/null 2>&1
			else
				ui_print "    * Uninstalling user app..."
				pmex uninstall --user 0 "$PKG_NAME" >/dev/null 2>&1
			fi

			# Re-read BASEPATH after uninstall/downgrade
			if BASEPATH=$(get_basepath); then
				if [ "${BASEPATH:1:4}" != data ]; then
					ui_print "[!] Detected $PKG_NAME as a factory system app"
					SCNM="/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
					mkdir -p /data/adb/post-fs-data.d
					echo "mount -t tmpfs none $BASEPATH" >"$SCNM"
					chmod +x "$SCNM"
					ui_print "    * Created post-fs-data early mount hide script."
					ui_print ""
					ui_print "[!] Reboot your device and re-flash this module!"
					abort
				fi
			fi
		fi

		if [ ! -f "$MODPATH/stock/base.apk" ]; then
			ui_print "[-] ERROR: Required stock base.apk not found!"
			abort
		fi
	fi
fi

install() {
	if [ ! -f "$MODPATH/stock/base.apk" ]; then
		abort "[-] ERROR: Stock $PKG_NAME apk was not found"
	fi
	install_err=""
	VERIF1=$(settings get global verifier_verify_adb_installs)
	VERIF2=$(settings get global package_verifier_enable)
	settings put global verifier_verify_adb_installs 0
	settings put global package_verifier_enable 0

	SZ=$(stat -c "%s" "$MODPATH"/stock/*.apk | awk '{sum += $0} END {print sum}')
	for IT in 1 2; do
		ui_print "[+] Installing: Upgrading/installing stock $PKG_NAME to $PKG_VER..."
		if ! SES=$(pmex install-create --user 0 -i com.android.vending -r -S "$SZ"); then
			ui_print "[-] ERROR: Package manager install-create failed"
			install_err="$SES"
			break
		fi
		SES=${SES#*[} SES=${SES%]*}

		for apki in "$MODPATH/stock"/*.apk; do
			set_perm "${apki}" 1000 1000 644 u:object_r:apk_data_file:s0
			ui_print "    * Writing $(basename "${apki}") (${SZ} bytes)..."
			if ! op=$(pmex install-write -S "$SZ" "$SES" "$(basename "${apki}")" "${apki}"); then
				ui_print "[-] ERROR: Package manager install-write failed"
				install_err="$op"
				break
			fi
		done
		if [ "$install_err" ]; then break; fi

		ui_print "    * Committing installation..."
		if ! op=$(pmex install-commit "$SES"); then
			ui_print "    * Commit failed: $op"
			if echo "$op" | grep -q -e INSTALL_FAILED_VERSION_DOWNGRADE -e INSTALL_FAILED_UPDATE_INCOMPATIBLE -e INSTALL_FAILED_DUPLICATE; then
				ui_print "[!] Alert: Installation conflict. Forcing complete uninstall..."
				ex_unins_arg=""
				if echo "$op" | grep -q INSTALL_FAILED_DUPLICATE; then
					ex_unins_arg="-k"
				fi
				if ! op=$(pmex uninstall --user 0 $ex_unins_arg "$PKG_NAME"); then
					ui_print "[-] ERROR: Full uninstall failed."
					if [ $IT = 2 ]; then
						install_err="[-] ERROR: pm uninstall failed."
						break
					fi
				fi
				continue
			fi
			ui_print "[-] ERROR: Package manager install-commit failed"
			install_err="$op"
			break
		fi
		if BASEPATH=$(get_basepath); then
			:
		else
			install_err=" "
			break
		fi
		break
	done
	settings put global verifier_verify_adb_installs "$VERIF1"
	settings put global package_verifier_enable "$VERIF2"
	if [ "$install_err" ]; then
		abort "$install_err"
	fi
}

if [ $INS = true ] && ! install; then abort; fi

BASEPATHLIB=${BASEPATH}/lib/${ARCH}
if [ $INS = true ] || [ -z "$(ls -A1 "$BASEPATHLIB")" ]; then
	ui_print "[+] Optimization: Extracting native libraries ($ARCH_LIB)..."
	if [ ! -d "$BASEPATHLIB" ]; then mkdir -p "$BASEPATHLIB"; else rm -f "$BASEPATHLIB"/* >/dev/null 2>&1 || :; fi
	if op=$(unzip -o -j "$MODPATH/stock/base.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB" 2>&1); then
		set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
		ui_print "    * Native libraries extracted successfully."
	else
		ui_print "[-] Warning: Extracting native libraries failed: '$op'"
	fi
fi

set_perm "$MODPATH/base.apk" 1000 1000 644 u:object_r:apk_data_file:s0

ui_print "[+] Security: Hiding patched APK in bizarre directory..."
mkdir -p "/data/adb/bizarre"
mv -f "$MODPATH/base.apk" "$RVPATH"

ui_print "[+] Mounting: Bind mounting patched APK onto target..."
if ! op=$(su -M -c mount -o bind "$RVPATH" "$BASEPATH/base.apk" 2>&1); then
	ui_print "[-] ERROR: Bind mount failed!"
	ui_print "    $op"
else
	ui_print "    * Bind mount successful."
fi
am force-stop "$PKG_NAME"

ui_print "[+] Optimization: Pre-compiling bytecode (speed-profile)..."
cmd package compile -m speed-profile -f "$PKG_NAME" >/dev/null 2>&1
ui_print "    * Compilation complete."

if [ -d "/data/data/$PKG_NAME/cache" ]; then
	ui_print "[+] Optimization: Cleaning application cache..."
	rm -rf "/data/data/$PKG_NAME/cache"/* >/dev/null 2>&1
	rm -rf "/data/data/$PKG_NAME/code_cache"/* >/dev/null 2>&1
fi

if [ "$KSU" ]; then
	ui_print "[+] KernelSU: Resolving application process profile..."
	DUMPSYS=$(dumpsys package "$PKG_NAME" 2>&1)
	UID=$(echo "$DUMPSYS" | grep -m1 uid=)
	UID=${UID#*=} UID=${UID%% *}
	if [ -z "$UID" ]; then
		UID=$(echo "$DUMPSYS" | grep -m1 userId=)
		UID=${UID#*=} UID=${UID%% *}
	fi
	if [ "$UID" ]; then
		ui_print "    * Target UID resolved: $UID"
		if ! OP=$("${MODPATH:?}/bin/$ARCH/ksu_profile" "$UID" "$PKG_NAME" 2>&1); then
			ui_print "    * Warning: $OP"
			ui_print "    * Recommended: In KernelSU app, disable 'Unmount modules' for $PKG_NAME"
		else
			ui_print "    * KernelSU profile configured successfully."
		fi
	else
		ui_print "[-] Warning: UID could not be found for $PKG_NAME"
	fi
fi

rm -rf "${MODPATH:?}/bin" "$MODPATH/stock/"
cp -f "$MODPATH/module.prop" "$MODPATH/module.prop.orig"

ui_print "========================================="
ui_print "    I N S T A L L A T I O N   D O N E    "
ui_print "========================================="
ui_print "    Enjoy your Bizarre modded app!       "
ui_print "    By Abhishek Babu                     "
ui_print "========================================="
ui_print ""
