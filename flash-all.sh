#!/bin/bash

IMAGES_PATH=$HOME/android/images

# slot to write images to
# TODO: support flashing both slots at one time
SLOT=a

# path to folder containing partition images
# e.g. from extracted OTA
ANDROID_VERSION=11
PARTITION_IMAGES=$IMAGES_PATH/oxygenos$ANDROID_VERSION/

# path to recovery image, e.g. twrp-3.x.x-fajita.img
# twrp-3.6.0_9-0 works with OxygenOS 11
# twrp-3.3.1-1 works with OxygenOS 9
# TODO: calculate from $ANDROID_VERSION, or similar
RECOVERY_IMAGE=$IMAGES_PATH/twrp/twrp-3.6.0_9-0-fajita.img


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
	india
	mdtp
	mdtpsecapp
	modem
	odm
	oem_dycnvbk
	oem_stanvbk
	qupfw
	# reserve
	storsec
	system
	vbmeta
	vendor
)

critical_partitions=(
	abl
	cmnlib64
	cmnlib
	devcfg
	hyp
	keymaster
	xbl
	xbl_config
)


#####################
# NORMAL PARTITIONS #
#####################

adb reboot bootloader
fastboot set_active $SLOT

if [[ $REPLY =~ ^[Yy]$ ]]
then
	# iterate partitions
	for i in "${partitions[@]}"
	do
		src=$PARTITION_IMAGES/$i.img
		if [ -f "$src" ]; then
			echo "Writing $i to slot $SLOT"
			# echo "fastboot flash $i"_"$SLOT $src"
			fastboot flash $i"_"$SLOT $src || echo "Failed to flash $i to slot $SLOT"
		else 
			# file not in extracted payload...
			echo "$src not found in images folder, skipping..."
		fi
	done
fi


#######################
# CRITICAL PARTITIONS #
#######################

echo "Starting recovery on the phone"
echo ""
fastboot reboot bootloader
fastboot boot $RECOVERY_IMAGE

read -p "Wait for recovery to start before continuing. Continue [Y/N]?" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]
then
	# iterate critical_partitions
	for i in "${critical_partitions[@]}"
	do
		src=$PARTITION_IMAGES/$i.img
		if [ -f "$src" ]; then
			# try push file to /tmp
			if adb push $src /tmp; then
				echo "Pushed $src to /tmp"
				echo "Writing $i to slot $SLOT"
				# try "flash" img to partition
				adb shell dd if=/tmp/$i.img of=/dev/block/bootdevice/by-name/$i_$SLOT || echo "Failed to flash $i to slot $SLOT"
				echo "Deleting $i from /tmp"
				# delete file after flashing
				adb shell rm /tmp/$i.img
				echo "Done"
			else
				echo "Failed to push $src to /tmp"
			fi
		else 
			# file not in extracted payload...
			echo "$src not found in images folder, skipping..."
		fi
	done
fi
