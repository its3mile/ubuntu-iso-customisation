#! /usr/bin/bash

# define base image and container image tag
INPUT_UBUNTU_ISO=${1:-ubuntu-24.04.2-live-server-amd64.iso}
BASE_UBUNTU_IMAGE_TAG=${2:-24.04}
OUTPUT_UBUNTU_ISO=${3:-ubuntu-24.04.2-custom-live-server-amd64.iso}

# build container image
docker build \
    --tag iso-builder-sandbox-image \
    --build-arg BASE_UBUNTU_IMAGE_TAG="${BASE_UBUNTU_IMAGE_TAG}" \
    --build-arg INPUT_UBUNTU_ISO="${INPUT_UBUNTU_ISO}" \
    --build-arg OUTPUT_UBUNTU_ISO="${OUTPUT_UBUNTU_ISO}" \
    .

# run container to create customised image
docker run \
    --privileged \
    --name iso-builder-sandbox \
    iso-builder-sandbox-image

# extract customised image from container
docker cp "iso-builder-sandbox:/workspace/$(basename "${OUTPUT_UBUNTU_ISO}")" "${OUTPUT_UBUNTU_ISO}"

# remove container
docker rm iso-builder-sandbox

# remove image
docker image rm iso-builder-sandbox-image
