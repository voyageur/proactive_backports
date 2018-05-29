#!/bin/bash

cloner='git clone https://git.openstack.org/'

for arg in "$@"; do
    read -ra arg <<< $(echo $arg | tr "/" " ")
    if [ ${#arg[@]} -eq 2 ]; then
        namespace=${arg[0]}
        project=${arg[1]}
    else
        namespace=openstack
        project=${arg[0]}
    fi
    full_project=${namespace}/${project}

    if ! [ -d "${project}" ]; then
        ${cloner}${full_project}
    fi

    echo "$PWD/$project"
done

exit 0
