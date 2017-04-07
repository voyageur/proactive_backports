#!/bin/sh

# This is a workaround for kernel bug where rmmod spins cpu to 100% on brcmfmac wifi
# https://bugzilla.redhat.com/show_bug.cgi?id=1397274

set -x

sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
