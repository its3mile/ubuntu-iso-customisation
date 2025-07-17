#! /usr/bin/bash

ISO=$1

# mount base image
mkdir isomount && \
    mount "${ISO}" isomount

# extract base system
mkdir extracted && \
    rsync --exclude=/casper/filesystem.squashfs -a isomount/ extracted

# extract squashfs system (this is the installed system, not the live cd system) 
unsquashfs isomount/casper/ubuntu-server-minimal.squashfs
mv squashfs-root edit

# bind host directories to prepare for chroot into expanded squashfs system
mount --bind /run edit/run
mount --bind /proc edit/proc
mount --bind /sys edit/sys
mount --bind /dev edit/dev
mount --bind /dev/pts edit/dev/pts

# copy in host's host file to prepare for chroot into expanded squashfs system
cp /etc/hosts edit/etc/

# chroot and make customisations
chroot edit /bin/bash <<EOF

# debug
echo $SHELL 

# non-interactive
export DEBIAN_FRONTEND=noninteractive

# update apt sources
apt-get update

# install some custom packages
apt-get install -y micro neofetch

# cleanup before chroot exit
apt-get autoremove
apt-get clean
rm -rf /tmp/* ~/.bash_history
rm /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
EOF

# umount host directories
umount edit/run
umount edit/proc
umount edit/sys
umount edit/dev/pts
umount edit/dev

# cleanup system bash history
rm edit/root/.bash_history

# recreate squashfs system and associated metadata files
chmod +w extracted/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extracted/casper/filesystem.manifest
cp extracted/casper/ubuntu-server-minimal.manifest extracted/casper/ubuntu-server-minimal.manifest-custom
sed -i '/ubiquity/d' extracted/casper/ubuntu-server-minimal.manifest-custom
sed -i '/casper/d' extracted/casper/ubuntu-server-minimal.manifest-custom
rm extracted/casper/ubuntu-server-minimal.squashfs
rm extracted/casper/ubuntu-server-minimal.squashfs.gpg
mksquashfs edit extracted/casper/ubuntu-server-minimal.squashfs -comp xz
printf %s "$(du -sx --block-size=1 edit | cut -f1)" > extracted/casper/ubuntu-server-minimal.size
pushd extracted || exit 
rm md5sum.txt
find . -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
popd || exit

# extract master boot record partition from base system
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

# shellcheck disable=SC2086
eval xorriso  -indev "${ISO}" --outdev MyDistribution.iso -map extracted / -- ${ARGS}
