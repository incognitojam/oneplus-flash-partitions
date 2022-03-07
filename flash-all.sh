#!/bin/bash

# example file tree
# ~
#   android
#     images
#       fajita
#         oxygenos9
#           abl.img
#           aop.img
#           bluetooth.img
#           boot.img
#           ...
#           xbl.img
#         oxygenos11
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

# folder containing android system images...
IMAGES_PATH=$HOME/android/images/fajita

# slot to write images to
# TODO: support flashing both slots at one time
SLOT=b

# path to folder containing partition images
# e.g. from extracted OTA
PARTITION_IMAGES=$IMAGES_PATH/oxygenos11

# path to recovery image, e.g. twrp-3.x.x-fajita.img
# twrp-3.6.0_9-0 works with OxygenOS 11
# twrp-3.3.1-1 works with OxygenOS 9
RECOVERY_IMAGE=$IMAGES_PATH/twrp/twrp-3.6.0_9-0-fajita.img


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
	india
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
# reserve

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

echo "Preparing fastboot in slot $SLOT on the phone"
echo ""
adb reboot bootloader
fastboot set_active $SLOT

# iterate partitions
for i in "${partitions[@]}"; do
	echo $i
	src=$PARTITION_IMAGES/$i.img
	echo -n "	Checking file exists... "
	if [ -f "$src" ]; then
		echo "found!"
		echo "	Writing $i to slot $SLOT..."
		if ! fastboot flash $i"_"$SLOT $src; then
			echo "	Failed!"
		fi
		echo ""
	else
		# file not in extracted payload...
		echo "not found"
	fi
done

echo "Finished writing normal partitions"


#######################
# CRITICAL PARTITIONS #
#######################

# TODO: figure out which normal partitions we need to flash before recovery can boot, and then
# do all of the rest from recovery

fastboot reboot bootloader
echo "Starting recovery on the phone"
fastboot boot $RECOVERY_IMAGE

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
			if adb push $src /tmp; then
				echo "done"
				echo -n "	Writing $i to slot $SLOT... "
				# try "flash" img to partition
				# TODO: maybe we don't need to append $SLOT for /dev/block/bootdevice/by-name (as opposed to /dev/block/by-name)
				adb shell dd if=/tmp/$i.img of=/dev/block/bootdevice/by-name/$i_$SLOT || echo "failed" && echo "done"
				echo "	Deleting $i from /tmp... "
				# delete file after flashing
				adb shell rm /tmp/$i.img || echo "failed" && echo "done"
			else
				echo "failed"
			fi
		else 
			# file not in extracted payload...
			echo "not found"
		fi
	done
fi

echo "Finished flashing to slot $SLOT"
