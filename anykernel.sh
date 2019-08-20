# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Yuka Kernel
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=1
do.initd=1
do.force_encryption=0
do.f2fs_patch=1
do.rem_encryption=0
device.name1=land
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/mmcblk0p21;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


# Get option from zip name if applicable
case $(basename $ZIP) in
  *new*|*New*|*NEW*) NEW=true;;
  *old*|*Old*|*OLD*) NEW=false;;
esac

# Change this path to wherever the keycheck binary is located in your installer
KEYCHECK=$INSTALLER/keycheck
chmod 755 $KEYCHECK

keytest() {
  ui_print "- Vol Key Test -"
  ui_print "   Press a Vol Key:"
  (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events) || return 1
  return 0
}   

choose() {
  #note from chainfire @xda-developers: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
  while true; do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events
    if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

chooseold() {
  # Calling it first time detects previous input. Calling it second time will do what we want
  $KEYCHECK
  $KEYCHECK
  SEL=$?
  if [ "$1" == "UP" ]; then
    UP=$SEL
  elif [ "$1" == "DOWN" ]; then
    DOWN=$SEL
  elif [ $SEL -eq $UP ]; then
    return 0
  elif [ $SEL -eq $DOWN ]; then
    return 1
  else
    ui_print "   Vol key not detected!"
    abort "   Use name change method in TWRP"
  fi
}
ui_print " "
if [ -z $NEW ]; then
  if keytest; then
    FUNCTION=choose
  else
    FUNCTION=chooseold
    ui_print "   ! Legacy device detected! Using old keycheck method"
    ui_print " "
    ui_print "- Vol Key Programming -"
    ui_print "   Press Vol Up Again:"
    $FUNCTION "UP"
    ui_print "   Press Vol Down"
    $FUNCTION "DOWN"
  fi
  ui_print " "
  ui_print "- Select Option -"
  ui_print " "
  ui_print "   Do you want to enable dt2w by default?"
  ui_print " "
  ui_print "   Vol Up   =  Yes"
  ui_print "   Vol Down =  No"
  if $FUNCTION; then 
    NEW=true
  else 
    NEW=false
  fi
else
  ui_print "   Option specified in zipname!"
fi

if $NEW; then
  ui_print " "
  ui_print "- DT2W now enabled by default..."
  cp tools/yuka/Edt2w/* $ramdisk/
  
else
  ui_print " "
  ui_print "- DT2W now disabled by default..."
  cp tools/yuka/Ddt2w/* $ramdisk/
fi


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;


## AnyKernel install
dump_boot;

# begin ramdisk changes

# fstab.qcom
if [ -e fstab.qcom ]; then
	fstab=fstab.qcom;
elif [ -e /system/vendor/etc/fstab.qcom ]; then
	fstab=/system/vendor/etc/fstab.qcom;
elif [ -e /system/etc/fstab.qcom ]; then
	fstab=/system/etc/fstab.qcom;
fi;

if [ "$(file_getprop $script do.f2fs_patch)" == 1 ]; then
	if [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
	   [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
		ui_print " "; ui_print "Found fstab: $fstab";
		ui_print "- Adding f2fs support to fstab...";

		insert_line $fstab "data        f2fs" before "data        ext4" "/dev/block/bootdevice/by-name/userdata     /data        f2fs    nosuid,nodev,noatime,inline_xattr,data_flush      wait,check,encryptable=footer,formattable,length=-16384";
		insert_line $fstab "cache        f2fs" after "data        ext4" "/dev/block/bootdevice/by-name/cache     /cache        f2fs    nosuid,nodev,noatime,inline_xattr,flush_merge,data_flush wait,formattable,check";

		if [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
			ui_print "- Failed to add f2fs support!";
			exit 1;
		fi;
	elif [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
	     [ $(cat $fstab | grep f2fs | wc -l) -gt "0" ]; then
		ui_print " "; ui_print "Found fstab: $fstab";
		ui_print "- F2FS supported!";
	fi;
fi; #f2fs_patch

if [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is enabled";
	if [ "$(file_getprop $script do.rem_encryption)" == 0 ]; then
		ui_print "- Force encryption removal is off!";
	else
		ui_print "- Force encryption removal is on!";
	fi;
elif [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is not enabled";
	if [ "$(file_getprop $script do.force_encryption)" == 0 ]; then
		ui_print "- Force encryption is off!";
	else
		ui_print "- Force encryption is on!";
	fi;
fi;

if [ "$(file_getprop $script do.rem_encryption)" == 1 ] &&
   [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	sed -i 's/forceencrypt/encryptable/g' $fstab
	if [ $(cat $fstab | grep forceencrypt | wc -l) -eq "0" ]; then
		ui_print "- Removed force encryption flag!";
	else
		ui_print "- Failed to remove force encryption!";
		exit 1;
	fi;
elif [ "$(file_getprop $script do.force_encryption)" == 1 ] &&
     [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	sed -i 's/encryptable/forceencrypt/g' $fstab
	if [ $(cat $fstab | grep encryptable | wc -l) -eq "0" ]; then
		ui_print "- Added force encryption flag!";
	else
		ui_print "- Failed to add force encryption!";
		exit 1;
	fi;
fi;

# init.rc
backup_file init.rc;
replace_string init.rc "cpuctl cpu,timer_slack" "mount cgroup none /dev/cpuctl cpu" "mount cgroup none /dev/cpuctl cpu,timer_slack";
grep "import /init.spectrum.rc" init.rc >/dev/null || sed -i '1,/.*import.*/s/.*import.*/import \/init.spectrum.rc\n&/' init.rc
insert_line init.rc "init.yuka.rc" after "import /init.usb.rc" "import /init.yuka.rc";

# init.tuna.rc
backup_file init.tuna.rc;
insert_line init.tuna.rc "nodiratime barrier=0" after "mount_all /fstab.tuna" "\tmount ext4 /dev/block/platform/omap/omap_hsmmc.0/by-name/userdata /data remount nosuid nodev noatime nodiratime barrier=0";
append_file init.tuna.rc "bootscript" init.tuna;

# fstab.tuna
backup_file fstab.tuna;
patch_fstab fstab.tuna /system ext4 options "noatime,barrier=1" "noatime,nodiratime,barrier=0";
patch_fstab fstab.tuna /cache ext4 options "barrier=1" "barrier=0,nomblk_io_submit";
patch_fstab fstab.tuna /data ext4 options "data=ordered" "nomblk_io_submit,data=writeback";
append_file fstab.tuna "usbdisk" fstab;

# end ramdisk changes

write_boot;
## end install

# Add empty profile locations
if [ ! -d /data/media/Spectrum ]; then
	ui_print " "; ui_print "Creating /data/media/0/Spectrum...";
	mkdir /data/media/0/Spectrum;
fi
if [ ! -d /data/media/Spectrum/profiles ]; then
	mkdir /data/media/0/Spectrum/profiles;
fi
if [ ! -d /data/media/Spectrum/profiles/*.profile ]; then
	ui_print " "; ui_print "Creating empty profile files...";
	touch /data/media/0/Spectrum/profiles/balance.profile;
	touch /data/media/0/Spectrum/profiles/performance.profile;
	touch /data/media/0/Spectrum/profiles/battery.profile;
	touch /data/media/0/Spectrum/profiles/gaming.profile;
fi
