#!/bin/bash

# !!! The script assumes dbus-python is installed for secretstorage !!!

set -e

_dry=0

function dry {
    if [ $_dry -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

function die() { echo "$@" 1>&2 ; exit 1; }

containsElement () {
    local e
    for e in "${@:2}"; do
        [[ "$e" == "$1" ]] && return 0;
    done
    return 1
}

tag () {
    tag=$1
    all_bugs=$(echo "${@:2}" | tr " " "\n")
    if dry; then
        for bug in $all_bugs; do
            echo "Would tag bug $bug with $tag"
        done
    else
        echo $all_bugs | ./lp-tag.py "$tag"
    fi
}

# copy pasted from .bashrc
function goto {
    proj=$1
    mkdir -p ~/git
    cd ~/git
    cd $(os-clone.sh "$proj")
}

### MAIN ###

# -d means don't actually do any changes in external sources
while getopts "dp:s:" arg; do
    case $arg in
        d)
            _dry=1
            ;;
        p)
            project=$OPTARG
            ;;
        s)
            oldest=$OPTARG
            ;;
    esac
done
shift $((OPTIND-1))

# require project specified (atm only openstack/ namespace supported)
[ -n "$project" ] || die "project not specified"

# require start hash specified
[ -n "$oldest" ] || die "start hash not specified"

goto "openstack/$project"
project_dir=$PWD
git fetch origin

project_head=$(git show --oneline origin/master)

goto openstack-infra/release-tools
if ! [ -d .venv ]; then
    # dbus-python doesn't work from pypi, so
    # we need to rely on system package here
    virtualenv --system-site-packages .venv
    .venv/bin/pip install -e .

    # needed to access launchpad
    .venv/bin/pip install secretstorage

    # to import into trello
    # use booxter/ fork that supports unicode descriptions
    git clone https://github.com/booxter/filch.git .filch
    .venv/bin/pip install -e .filch
fi
. .venv/bin/activate

cmd="./bugs-fixed-since.py --repo $project_dir --start $oldest"

# calculate list of easy backports and all backports to be able to tag the
# former separately in trello
bugs=`${cmd} | \
      ./lp-filter-bugs-by-importance.py neutron --importance Wishlist | \
      ./lp-filter-bugs-by-importance.py neutron --importance Low | \
      ./lp-filter-bugs-by-importance.py neutron --importance Medium`

easy_bugs=`$cmd -e | \
      ./lp-filter-bugs-by-importance.py neutron --importance Wishlist | \
      ./lp-filter-bugs-by-importance.py neutron --importance Low | \
      ./lp-filter-bugs-by-importance.py neutron --importance Medium`

# tag bugs as potential backports in LP
tag neutron-proactive-backport-potential ${bugs}

# tag easy backportable bugs accordingly in LP
tag neutron-easy-proactive-backport-potential ${easy_bugs}

# also create cards in trello
for bug in ${easy_bugs}; do
    if dry; then
        echo "Would import bug $bug as easy backport"
    else
        filch-import --bug_id "$bug" -l EasyBackport -l ProactiveBackport --list_name='Proactive Backports'
    fi
done

for bug in $bugs; do
    if ! containsElement $bug $easy_bugs; then
        if dry; then
            echo "Would import bug $bug as usual backport"
        else
            filch-import --bug_id "$bug" -l ProactiveBackport --list_name='Proactive Backports'
        fi
    fi
done

# finally output the head of the project that we just triaged
echo "Triaged up to: $project_head"
exit 0
