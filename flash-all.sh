#!/bin/bash

# tool to help flash partitions using images, without reverting to the msm download tool to get
# the phone to a known good state.

# use payload_dumper to get imgs from payload.bin

# TODO:
# - figure out which partitions are important - do we really need to reflash everything
#   when it stops booting? probably not..
# - maybe download OTA packages
# - flash both slots at same time

# example file tree
# ~
#   android
#     images
#       fajita
#         OnePlus6TOxygen_34.J.61_OTA_0610_all_2109171644_7a4bfad9b1f940d5
#           payload.bin
#           abl.img
#           aop.img
#           bluetooth.img
#           boot.img
#           ...
#           xbl.img
#         twrp
#           twrp-3.3.1-1-fajita.img
#           twrp-3.4.0-1-fajita.img
#           ...

# find from adb devices or fastboot devices
DEVICE_SERIAL=6bf1ed7f

# folder containing android system images...
IMAGES_PATH=$HOME/android/images/fajita

# slot to write images to
# TODO: support flashing both slots at one time
SLOT=a

# path to folder containing partition images
# e.g. from extracted OTA
PARTITION_IMAGES=$IMAGES_PATH/oxygenos9

# path to recovery image, e.g. twrp-3.x.x-fajita.img
# twrp-3.6.0_9-0 works with OxygenOS 11
# twrp-3.3.1-1 works with OxygenOS 9
RECOVERY_IMAGE=$IMAGES_PATH/twrp/twrp-3.3.1-1-fajita.img


# note: partitions may be different in old/new OS versions...
# msm download tool is probably more reliable.
partitions=(
	LOGO
	aop
	bluetooth
	boot
	dsp
	dtbo
	fw_4j1ed
	fw_4u1ea
	fw_ufs3
	fw_ufs4
	fw_ufs5
	fw_ufs6
	fw_ufs7
	fw_ufs8
	mdtp
	mdtpsecapp
	modem
	odm
	oem_dycnvbk
	oem_stanvbk
	qupfw
	storsec
	system
	vbmeta
	vendor
)

# NOTE: india didn't seem to work as normal partition
critical_partitions=(
	abl
	cmnlib64
	cmnlib
	devcfg
	hyp
	india
	keymaster
	reserve
	tz
	xbl_config
	xbl
)

# india_a no such partition

# NOTE: i'm not sure if we should overwrite "reserve" partition too...


#####################
# NORMAL PARTITIONS #
#####################

echo "Preparing fastboot in slot $SLOT on the phone"
echo ""
adb -s $DEVICE_SERIAL reboot bootloader
fastboot -s $DEVICE_SERIAL set_active $SLOT

# iterate partitions
for i in "${partitions[@]}"; do
	echo $i
	src=$PARTITION_IMAGES/$i.img
	echo -n "	Checking file exists... "
	if [ -f "$src" ]; then
		echo "found!"
		echo "	Writing $i..."
		if ! fastboot -s $DEVICE_SERIAL flash $i $src ; then
			echo "	Failed!"
		fi
	else
		# file not in extracted payload...
		echo "not found"
	fi
	echo ""
done

echo "Finished writing normal partitions"


#######################
# CRITICAL PARTITIONS #
#######################

# TODO: figure out which normal partitions we need to flash before recovery can boot, and then
# do all of the rest from recovery

echo "Starting recovery on the phone"
fastboot -s $DEVICE_SERIAL reboot bootloader
fastboot -s $DEVICE_SERIAL boot $RECOVERY_IMAGE

read -p "Wait for recovery to start before continuing. Continue [Y/N]?" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
	# iterate critical_partitions
	for i in "${critical_partitions[@]}"; do
		echo $i
		echo "	Checking file exists... "
		src=$PARTITION_IMAGES/$i.img
		if [ -f "$src" ]; then
			echo "found!"
			# try push file to /tmp
			echo -n "	Pushing $src to /tmp... "
			if adb -s $DEVICE_SERIAL push $src /tmp; then
				echo "done"
				echo -n "	Writing $i... "
				# try "flash" img to partition
				# FIXED: maybe we don't need to append $SLOT for /dev/block/bootdevice/by-name (as opposed to /dev/block/by-name)
				adb -s $DEVICE_SERIAL shell dd if=/tmp/$i.img of=/dev/block/bootdevice/by-name/$i bs=1m || echo "failed" && echo "done"
				echo "	Deleting $i from /tmp... "
				# delete file after flashing
				adb -s $DEVICE_SERIAL shell rm /tmp/$i.img || echo "failed" && echo "done"
			else
				echo "failed"
			fi
		else 
			# file not in extracted payload...
			echo "not found"
		fi
		echo ""
	done
fi

echo "Finished flashing to slot $SLOT"
echo ""

read -p "Do you want to reboot? [Y/N]" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
	adb reboot
fi
