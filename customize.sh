#!/system/bin/sh

SKIPUNZIP=1
SKIPMOUNT=true
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

if [ "$BOOTMODE" != true ]; then
  abort "-----------------------------------------------------------"
  ui_print "! Please install in Magisk/KernelSU/APatch Manager"
  ui_print "! Install from recovery is NOT supported"
  abort "-----------------------------------------------------------"
elif [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "-----------------------------------------------------------"
  ui_print "! Please update your KernelSU and KernelSU Manager"
  abort "-----------------------------------------------------------"
fi

service_dir="/data/adb/service.d"
if [ "$KSU" = "true" ]; then
  ui_print "— KernelSU version: $KSU_VER ($KSU_VER_CODE)"
  [ "$KSU_VER_CODE" -lt 10683 ] && service_dir="/data/adb/ksu/service.d"
elif [ "$APATCH" = "true" ]; then
  APATCH_VER=$(cat "/data/adb/ap/version")
  ui_print "— APatch version: $APATCH_VER"
else
  ui_print "— Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
fi

mkdir -p "${service_dir}"
if [ -d "/data/adb/modules/box_for_magisk" ]; then
  rm -rf "/data/adb/modules/box_for_magisk"
  ui_print "— Old module deleted."
fi

ui_print "— Installing Box for Magisk/KernelSU/APatch"
unzip -o "$ZIPFILE" -x 'META-INF/*' -x 'webroot/*' -d "$MODPATH" >&2
if [ -d "/data/adb/box" ]; then
  ui_print "— Backup existing box data"
  temp_bak=$(mktemp -d "/data/adb/box/box.XXXXXXXXXX")
  temp_dir="${temp_bak}"
  mv /data/adb/box/* "${temp_dir}/"
  mv "$MODPATH/box/"* /data/adb/box/
  backup_box="true"
else
  mv "$MODPATH/box" /data/adb/
fi

ui_print "— Create directories..."
mkdir -p /data/adb/box/ /data/adb/box/run/ /data/adb/box/bin/

ui_print "— Extracting..."
unzip -j -o "$ZIPFILE" 'uninstall.sh' -d "$MODPATH" >&2
unzip -j -o "$ZIPFILE" 'box_service.sh' -d "${service_dir}" >&2
unzip -j -o "$ZIPFILE" 'sbfr' -d "$MODPATH" >&2

ui_print "— Setting permissions..."
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive /data/adb/box/ 0 3005 0755 0644
set_perm_recursive /data/adb/box/scripts/ 0 3005 0755 0700
set_perm ${service_dir}/box_service.sh 0 0 0755
set_perm $MODPATH/uninstall.sh 0 0 0755
set_perm $MODPATH/sbfr 0 0 0755
chmod ugo+x ${service_dir}/box_service.sh $MODPATH/uninstall.sh /data/adb/box/scripts/*

apply_mirror() {
  ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ui_print "— Do you want to use the 'ghfast.top' ?"
  ui_print "     ↳  mirror to speed up downloads"
  ui_print "— [ Vol UP(+): Yes ]"
  ui_print "— [ Vol DOWN(-): No ]"
  START_TIME=$(date +%s)
  while true ; do
    NOW_TIME=$(date +%s)
    timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"
    if [ $(( NOW_TIME - START_TIME )) -gt 9 ]; then
      ui_print "— No input detected after 10 seconds. Default: Yes"
      sed -i 's/use_ghproxy=.*/use_ghproxy="true"/' /data/adb/box/scripts/box.tool
      break
    elif grep -q KEY_VOLUMEUP "$TMPDIR/events"; then
      ui_print "— ghfast acceleration enabled."
      sed -i 's/use_ghproxy=.*/use_ghproxy="true"/' /data/adb/box/scripts/box.tool
      break
    elif grep -q KEY_VOLUMEDOWN "$TMPDIR/events"; then
      ui_print "— ghfast acceleration disabled."
      sed -i 's/use_ghproxy=.*/use_ghproxy="false"/' /data/adb/box/scripts/box.tool
      break
    fi
  done
}

apply_mirror
timeout 1 getevent -cl >/dev/null

find_bin() {
  bin_dir="$temp_bak"

  check_bin() {
    local name="$1"
    local path="$bin_dir/bin/$name"
    if [ -e "$path" ]; then
        ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ui_print "— $name → ⭕ FOUND"
    else
        ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ui_print "— $name → ❌ NOT FOUND"
    fi
  }

  handle_download() {
    local bin="$1"
    local action=""
    case "$bin" in
      yq) action="upyq" ;;
      curl) action="upcurl" ;;
      *) action="all $bin" ;;
    esac

    START_TIME=$(date +%s)
    while true; do
      NOW_TIME=$(date +%s)
      timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"
      
      if [ $(( NOW_TIME - START_TIME )) -gt 9 ]; then
        ui_print "— No input detected. Skipping $bin."
        break
      elif grep -q KEY_VOLUMEUP "$TMPDIR/events"; then
        ui_print "— Download/Update starting..."
        /data/adb/box/scripts/box.tool $action
        break
      elif grep -q KEY_VOLUMEDOWN "$TMPDIR/events"; then
        ui_print "— Download disabled."
        break
      fi
    done
  }

  for bin in yq curl sing-box; do
    timeout 1 getevent -cl >/dev/null
    check_bin "$bin"
    ui_print "— Do you want to download or update $bin?"
    ui_print "— [ Vol UP(+): Yes ]"
    ui_print "— [ Vol DOWN(-): No ]"
    handle_download "$bin"
    sleep 1
  done
}

find_bin
timeout 1 getevent -cl >/dev/null

restore_ini() {
  backup_ini="$temp_dir/settings.ini"
  target_ini="/data/adb/box/settings.ini"
  keys="network_mode bin_name ipv6 xclash_option renew update_subscription subscription_url_clash subscription_url_singbox name_clash_config clash_config name_provide_clash_config clash_provide_path enable_network_service_control use_module_on_wifi_disconnect use_module_on_wifi use_ssid_matching use_wifi_list_mode wifi_ssids_list inotify_log_enabled"
  
  for key in $keys; do
      value=$(grep "^$key=" "$backup_ini")
      if [ -n "$value" ]; then
          esc_value=$(printf '%s\n' "$value" | sed -e 's/[&/\]/\\&/g')
          if grep -q "^$key=" "$target_ini"; then
              sed -i "s|^$key=.*|$esc_value|" "$target_ini"
          else
              echo "$value" >> "$target_ini"
          fi
          ui_print "— Restored: $key"
      fi
  done
}

apply_ini() {
  ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ui_print "— Would you like to restore settings.ini?"
  ui_print "— [ Vol UP(+): Yes ]"
  ui_print "— [ Vol DOWN(-): No ]"
  START_TIME=$(date +%s)
  while true ; do
    NOW_TIME=$(date +%s)
    timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"
    if [ $(( NOW_TIME - START_TIME )) -gt 9 ]; then
      ui_print "— Skipped restoring settings.ini"
      break
    elif grep -q KEY_VOLUMEUP "$TMPDIR/events"; then
      restore_ini
      break
    elif grep -q KEY_VOLUMEDOWN "$TMPDIR/events"; then
      ui_print "— Skipped restoring settings.ini"
      break
    fi
  done
}

apply_ini
timeout 1 getevent -cl >/dev/null

if [ "${backup_box}" = "true" ]; then
  ui_print "— Restoring sing-box configurations..."
  [ -d "${temp_dir}/sing-box" ] && cp -rf "${temp_dir}/sing-box/"* "/data/adb/box/sing-box/"

  restore_kernel() {
    kernel_name="$1"
    if [ ! -f "/data/adb/box/bin/$kernel_name" ] && [ -f "${temp_dir}/bin/${kernel_name}" ]; then
      ui_print "— Restoring ${kernel_name}..."
      cp -rf "${temp_dir}/bin/${kernel_name}" "/data/adb/box/bin/${kernel_name}"
    fi
  }

  for kernel in yq curl sing-box; do
    restore_kernel "$kernel"
  done

  ui_print "— Restoring runtime data..."
  cp -rf "${temp_dir}/run/"* "/data/adb/box/run/"
  cp -rf "${temp_dir}/ap.list.cfg" "/data/adb/box/ap.list.cfg"
  cp -rf "${temp_dir}/crontab.cfg" "/data/adb/box/crontab.cfg"
  cp -rf "${temp_dir}/package.list.cfg" "/data/adb/box/package.list.cfg"
fi

[ -z "$(find /data/adb/box/bin -type f)" ] && sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ 😱 Manual sing-box download required ] /g' $MODPATH/module.prop

if [ "$KSU" = "true" ]; then
  sed -i "s/name=.*/name=Box for MidoriSU/g" $MODPATH/module.prop
elif [ "$APATCH" = "true" ]; then
  sed -i "s/name=.*/name=Box for APatch/g" $MODPATH/module.prop
else
  sed -i "s/name=.*/name=Box4Pixel/g" $MODPATH/module.prop
fi
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2

ui_print "— Cleaning up"
rm -rf /data/adb/box/bin/.bin $MODPATH/box $MODPATH/box_service.sh

ln -sf "$MODPATH/sbfr" /dev/sbfr
ui_print "— Shortcut '/dev/sbfr' created. Run: su -c /dev/sbfr"
ui_print "— Installation complete. Reboot device."
