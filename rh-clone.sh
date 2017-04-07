#!/bin/sh

set -x

package=$1

cd ~/rhosp
if [ -d "$package" ]; then
    exit 0
fi

rhpkg clone $package
cd $package
git remote add rhos -f ssh://ihrachys@code.engineering.redhat.com:22/neutron
exit 0
