#! /usr/bin/bash

INPUT_ISO=$1
OUTPUT_ISO=$2
TARGET_SYSTEM_NAME=ubuntu-server-minimal

# mount base image
mkdir isomount
mount --read-only "${INPUT_ISO}" isomount

# extract base system
mkdir extracted
rsync -a isomount/ \
    --exclude=/casper/${TARGET_SYSTEM_NAME}.manifest \
    --exclude=/casper/${TARGET_SYSTEM_NAME}.size \
    --exclude=/casper/${TARGET_SYSTEM_NAME}.squashfs \
    --exclude=/casper/${TARGET_SYSTEM_NAME}.squashfs.gpg \
   extracted

# extract target system
unsquashfs isomount/casper/${TARGET_SYSTEM_NAME}.squashfs
mv squashfs-root edit

umount isomount
rmdir isomount 

# bind host directories
mount --bind /run edit/run
mount --bind /proc edit/proc
mount --bind /sys edit/sys
mount --bind /dev edit/dev
mount --bind /dev/pts edit/dev/pts

# copy in host's host file
cp /etc/hosts edit/etc/

# copy in target customisations
mkdir -p edit/etc/customisations/target
cp -r customisations/target edit/etc/customisations

# chroot and make customisations
chroot edit /bin/bash << EOF

# non-interactive
export DEBIAN_FRONTEND=noninteractive

# update apt sources
apt-get update

# add docker repository
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# install packages
xargs --arg-file=/etc/customisations/target/packages.txt --no-run-if-empty \
  apt-get install --no-install-recommends --yes

# cleanup before chroot exit
apt-get autoremove
apt-get clean
rm -rf /tmp/* ~/.bash_history
rm -f /var/lib/dbus/machine-id
rm -f /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
EOF

# umount host directories
umount edit/run
umount edit/proc
umount edit/sys
umount edit/dev/pts
umount edit/dev

# cleanup target system bash history
rm -f edit/root/.bash_history

# cleanup target system tmp
rm -rf edit/tmp/*

# recreate target system and associated metadata files
chmod +w extracted/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extracted/casper/filesystem.manifest
chmod -w extracted/casper/filesystem.manifest
mksquashfs edit extracted/casper/${TARGET_SYSTEM_NAME}.squashfs -comp xz

# add autoinstall
# this is executed automatically on first boot by subiquity
# https://canonical-subiquity.readthedocs-hosted.com/en/latest/tutorial/providing-autoinstall.html
# https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html
cp customisations/live/autoinstall.yaml extracted/autoinstall.yaml

# recalculate md5s
FS_SIZE=$(printf %s "$(du -sx --block-size=1 edit | cut -f1)")
echo "${FS_SIZE}" > extracted/casper/${TARGET_SYSTEM_NAME}.size
pushd extracted || exit 
rm md5sum.txt
find . -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
popd || exit

# extract boot code from master boot record partition from base system - this is always the first 446 bytes of the first sector
dd bs=1 count=446 if="${INPUT_ISO}" of=mbr.img

# extract efi partition from base system
SECTOR_SIZE=$(fdisk -l ${INPUT_ISO} | grep "Units" | awk '{print $8}')
EFI_PART_OFFSET=$(fdisk -l ${INPUT_ISO} | grep "EFI System" | awk '{print $2}')
EFI_PART_SECTORS=$(fdisk -l ${INPUT_ISO} | grep "EFI System" | awk '{print $4}')
dd bs="${SECTOR_SIZE}" count="${EFI_PART_SECTORS}" skip="${EFI_PART_OFFSET}" if=${INPUT_ISO} of=EFI.img

# create customised image
REPORT=$(xorriso -indev "${INPUT_ISO}" -report_el_torito cmd)
echo "${REPORT}" 

ARGS=$(echo "${REPORT}" | sed -E "s#(-boot_image grub grub2_mbr=)[^[:space:]]*#\1mbr.img#" | sed -E "s#(-append_partition[[:space:]]+2[[:space:]]+[a-f0-9]+)[[:space:]]+--interval:imported_iso:[^[:space:]]+#\1 EFI.img #")
echo $ARGS

eval xorriso  -indev "${INPUT_ISO}" --outdev "$(basename "${OUTPUT_ISO}")" -map extracted / -- ${ARGS}

# set output iso permissions to the same as input ISO (instead of root)
chown --reference="${INPUT_ISO}" "$(basename "${OUTPUT_ISO}")"
chmod --reference="${INPUT_ISO}" "$(basename "${OUTPUT_ISO}")"
