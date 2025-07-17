ARG UBUNTU_IMAGE_TAG=24.04
FROM ubuntu:${UBUNTU_IMAGE_TAG}

# install required packages for image customisation
RUN apt-get update -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y apparmor \
                    apparmor-utils \
                    bridge-utils \
                    libvirt-clients \
                    libvirt-daemon-system \
                    libguestfs-tools \
                    qemu-kvm \
                    virt-manager \
                    binwalk \
                    casper \
                    genisoimage \
                    live-boot \
                    live-boot-initramfs-tools \
                    squashfs-tools \
                    tree && \
    apt-get autoremove \
    && apt-get clean

# define workspace
RUN mkdir /workspace
WORKDIR /workspace

# copy in base image
# this must also persist for runtime (not just compile time)
ARG UBUNTU_ISO
ENV UBUNTU_ISO=${UBUNTU_ISO}
COPY ${UBUNTU_ISO} .

# copy in build script
COPY build.sh build.sh
RUN chmod +x build.sh

# execute build script
CMD ["bash", "-c", "./build.sh $(basename ${UBUNTU_ISO})"]
