#! /usr/bin/bash

ISO=$1
TARGET_SYSTEM_NAME=ubuntu-server-minimal

# mount base image
mkdir isomount
mount --read-only "${ISO}" isomount

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

# chroot and make customisations
chroot edit /bin/bash << EOF

# non-interactive
export DEBIAN_FRONTEND=noninteractive

# update apt sources
apt-get update

# install some custom packages
apt-get install -y neofetch

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
cat << EOF | tee extracted/autoinstall.yaml
#cloud-config
autoinstall:
  version: 1
  interactive-sections:
    - network
    - identity
  early-commands:
    - echo "Hello, World!"
  storage:
    layout:
      name: lvm
  locale: en_GB
  keyboard:
    layout: gb
    variant: ""
  source:
    search-drivers: false
    id: ubuntu-server 
  late-commands:
    - sed -ie 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/' /target/etc/default/grub
    - echo "Goodbye, World!"
EOF

# recalculate md5s
FS_SIZE=$(printf %s "$(du -sx --block-size=1 edit | cut -f1)")
echo "${FS_SIZE}" > extracted/casper/${TARGET_SYSTEM_NAME}.size
pushd extracted || exit 
rm md5sum.txt
find . -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
popd || exit

# extract boot code from master boot record partition from base system - this is always the first 446 bytes of the first sector
dd bs=1 count=446 if="${ISO}" of=mbr.img

# extract efi partition from base system
SECTOR_SIZE=$(fdisk -l ${ISO} | grep "Units" | awk '{print $8}')
EFI_PART_OFFSET=$(fdisk -l ${ISO} | grep "EFI System" | awk '{print $2}')
EFI_PART_SECTORS=$(fdisk -l ${ISO} | grep "EFI System" | awk '{print $4}')
dd bs="${SECTOR_SIZE}" count="${EFI_PART_SECTORS}" skip="${EFI_PART_OFFSET}" if=${ISO} of=EFI.img

# create customised image
REPORT=$(xorriso -indev "${ISO}" -report_el_torito cmd)
echo "${REPORT}" 

ARGS=$(echo "${REPORT}" | sed -E "s#(-boot_image grub grub2_mbr=)[^[:space:]]*#\1mbr.img#" | sed -E "s#(-append_partition[[:space:]]+2[[:space:]]+[a-f0-9]+)[[:space:]]+--interval:imported_iso:[^[:space:]]+#\1 EFI.img #")
echo $ARGS

eval xorriso  -indev "${ISO}" --outdev MyDistribution.iso -map extracted / -- ${ARGS}
