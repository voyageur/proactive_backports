#!/bin/bash

set -e

cloner='zuul-cloner --color https://git.openstack.org'

if [ -z "${ZUUL_CACHE_DIR}" ]; then
    echo "Please define ZUUL_CACHE_DIR." 1>&2
    exit 1
fi
mkdir -p "${ZUUL_CACHE_DIR}"

for arg in "$@"; do
    arg=$(echo $arg | tr "/" "\n")
    if [ ${#arg[@]} -eq 2 ]; then
        namespace=${arg[0]}
        project=${arg[1]}
    else
        namespace=openstack
        project=${arg[0]}
    fi
    proj=${namespace}/${project}

    if ! [ -d "$ZUUL_CACHE_DIR/$proj" ]; then
        # first prepopulate cache
        pushd ${ZUUL_CACHE_DIR} 2>&1 > /dev/null
        ${cloner} ${proj}
        popd 2>&1 > /dev/null
    fi

    if ! [ -d "$proj" ]; then
        # now check out in current dir (from cache)
        ${cloner} ${proj}
    fi

    echo "$PWD/$proj"
done

exit 0
