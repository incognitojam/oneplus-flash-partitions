#!/bin/bash

# tool to help flash partitions using images, without reverting to the msm download tool to get
# the phone to a known good state.

# use payload_dumper to get imgs from payload.bin

# TODO:
# - figure out which partitions are important - do we really need to reflash everything
#   when it stops booting? probably not..
# - maybe download OTA packages
# - flash both slots at same time


# Copy env.sh.example to env.sh and modify as appropriate
source env.sh


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
