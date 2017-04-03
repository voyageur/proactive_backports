#!/bin/sh

set -x

sudo dnf install -y kernel-devel

cd /usr/src
sudo mkdir bcwc_pcie
sudo chown $(whoami):$(whoami) bcwc_pcie
git clone https://github.com/patjak/bcwc_pcie.git

cd bcwc_pcie/firmware
make
sudo make install

cd /usr/src/bcwc_pcie/
make

sudo make install
sudo depmod
sudo modprobe facetimehd
