#! /usr/bin/bash

# define base image and container image tag
UBUNTU_ISO=${1:-ubuntu-24.04.2-live-server-amd64.iso}
UBUNTU_IMAGE_TAG=${2:-24.04}

# build container image
docker build \
    --tag iso-builder-sandbox-image \
    --build-arg UBUNTU_IMAGE_TAG="${UBUNTU_IMAGE_TAG}" \
    --build-arg UBUNTU_ISO="${UBUNTU_ISO}" \
    .

# run container to create customised image
docker run \
    --privileged \
    --name iso-builder-sandbox \
    iso-builder-sandbox-image

# extract customised image from container
docker cp iso-builder-sandbox:/workspace/MyDistribution.iso MyDistribution.iso

# remove container image
docker rm iso-builder-sandbox
