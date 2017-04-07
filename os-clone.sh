#!/bin/sh

set -e
set -x

cloner='zuul-cloner https://git.openstack.org'

if [ -z "${ZUUL_CACHE_DIR}" ]; then
    echo "Please define ZUUL_CACHE_DIR." 1>&2
    exit 1
fi
mkdir -p "${ZUUL_CACHE_DIR}"

arg=$(echo $1 | tr "/" "\n")
if [ ${#arg[@]} -eq 2 ]; then
    namespace=${arg[0]}
    project=${arg[1]}
else
    namespace=openstack
    project=${arg[0]}
fi
proj=${namespace}/${project}

# first prepopulate cache
pushd ${ZUUL_CACHE_DIR}
${cloner} ${proj}
popd

# now check out in current dir (from cache)
${cloner} ${proj}

exit 0
