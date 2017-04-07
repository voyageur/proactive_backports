#!/bin/sh

set -e
set -x

arg=$(echo $1 | tr "/" "\n")

if [ ${#arg[@]} -eq 2 ]; then
    namespace=${arg[0]}
    project=${arg[1]}
else
    namespace=openstack
    project=${arg[0]}
fi

echo $namespace
echo $project

proj=${namespace}/${project}
clonedir=~/git/${proj}
if [ -d ${clonedir} ]; then
    exit 0
fi

mkdir -p ~/git/${namespace}
git clone https://git.openstack.org/${proj} ${clonedir}

exit 0
