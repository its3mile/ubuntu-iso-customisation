# Ubuntu ISO Customisation

## Description

Create a custom Ubuntu ISO
Tested on Ubuntu Server 24.04

This makes use of cloud-init/autoinstall added to subiquity for 24.04 editions of Ubuntu. 
It is therefore likely to work with the last few LTS Ubuntu Server editions (20.04 +), but only the latest LTS Ubuntu Desktop edition (24.04).

This replaces the ubuntu-server-minimal.squashfs, the default squashfs that becomes the target system, which all other included squashfs' build upon. Hence, whichever selection of Ubuntu is installed via subiquity, it will contain the customisations made.

# Dependencies
This simply requires docker, as the build is containerised, following recommendations that building of a Ubuntu ISO should be performed from within a system running the same version of Ubuntu.

## How to run

Download (and verify) Ubuntu Live Server 24.04

Execute 
`./run.sh <input ISO> <ubuntu edition docker tag> <output ISO>` 

e.g.,
`./run.sh ubuntu-24.04.2-live-server-amd64.iso 24.04 ubuntu-24.04.2-custom-live-server-amd64.iso`

n.b, `ubuntu-24.04.2-live-server-amd64.iso`, `24.04`, and `ubuntu-24.04.2-custom-live-server-amd64.iso` are default arguments, if unspecified.

## Info
A docker image is build containing the required tools as well as the \<input ISO\>, which is then used to create a container to perform the ISO customisation. The resultant ISO is then extracted from the container, to the \<output ISO\>, ready for testing.

The customisations are not exhaustively detailed, as this is provided as an example template.
- customisations/live/autoinstall.yaml: This is the cloud-init config that drives the subiquity installer. It is copied to the root in the customised ISO, which is the lowest priority, default location for it to be picked up by subiquity. Additional customisations can be applied to execute commands before, and after the installer, set up users and ssh keys, and configure networks and disk partitions.

- customisations/target/packages.txt: This is a list of packages that are installed via the build.sh script, when chroot'ed into target environment.

- build.sh: This is the script that performs all customisations, from extracting and unsquashing the input ISO, to chroot'ing and repacking the ISO. This can be adapted as desired to add to both the live environment, and the target environment.

