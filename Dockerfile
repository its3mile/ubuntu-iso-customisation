ARG BASE_UBUNTU_IMAGE_TAG=24.04
FROM ubuntu:${BASE_UBUNTU_IMAGE_TAG}

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

# copy in input iso
# this must also persist for runtime (not just compile time)
ARG INPUT_UBUNTU_ISO
ENV INPUT_UBUNTU_ISO=${INPUT_UBUNTU_ISO}
COPY ${INPUT_UBUNTU_ISO} .

# specify output iso
# this must also persist for runtime (not just compile time)
ARG OUTPUT_UBUNTU_ISO
ENV OUTPUT_UBUNTU_ISO=${OUTPUT_UBUNTU_ISO}

# copy in customisations
COPY customisations customisations

# copy in build script
COPY build.sh .

# make build script executable
RUN chmod +x ./build.sh

# execute build script
CMD ["bash", "-c", "./build.sh $(basename ${INPUT_UBUNTU_ISO}) $(basename ${OUTPUT_UBUNTU_ISO})"]
