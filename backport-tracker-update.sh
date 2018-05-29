#!/bin/bash

# !!! The script assumes dbus-python is installed for secretstorage !!!

set -e

TRELLO_BOARD="test-bc"
TRELLO_COLUMN="Proactive Backports"

GIT_DIR="/tmp/proactive-backports"
GIT_VENV="${GIT_DIR}/venv"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_dry=0

function die() { echo "$@" 1>&2 ; exit 1; }

function containsElement () {
    local e
    for e in "${@:2}"; do
        [[ "$e" == "$1" ]] && return 0;
    done
    return 1
}

function tag () {
    tag=$1
    all_bugs=$(echo "${@:2}" | tr " " "\n")
    if [ $_dry -eq 1 ]; then
        for bug in $all_bugs; do
            echo "Would tag bug $bug with $tag"
        done
    else
        echo "$all_bugs" | ./lp-tag.py "$tag"
    fi
}

function goto {
    proj=$1
    mkdir -p "${GIT_DIR}"
    cd "${GIT_DIR}"
    cd $("${SCRIPTS_DIR}"/os-clone.sh "$proj")
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

project_head=$(git log --oneline --no-walk origin/master)

goto openstack-infra/release-tools
if ! [ -d "${GIT_VENV}" ]; then
    # dbus-python doesn't work from pypi, so
    # we need to rely on system package here
    virtualenv-3 --system-site-packages "${GIT_VENV}"
    "${GIT_VENV}"/bin/pip install -e .

    # needed to access launchpad
    "${GIT_VENV}"/bin/pip install launchpadlib secretstorage


    "${GIT_VENV}"/bin/pip install git+https://github.com/rbrady/filch.git
fi
. "${GIT_VENV}"/bin/activate

cmd="./bugs-fixed-since.py --repo $project_dir --start $oldest"

# calculate list of easy backports and all backports to be able to tag the
# former separately in trello
bugs=`${cmd} | \
      ./lp-filter-bugs-by-importance.py $project --importance Wishlist | \
      ./lp-filter-bugs-by-importance.py $project --importance Low | \
      ./lp-filter-bugs-by-importance.py $project --importance Medium`

easy_bugs=`${cmd} -e | \
      ./lp-filter-bugs-by-importance.py $project --importance Wishlist | \
      ./lp-filter-bugs-by-importance.py $project --importance Low | \
      ./lp-filter-bugs-by-importance.py $project --importance Medium`

echo $easy_bugs
# tag bugs as potential backports in LP
tag $project-proactive-backport-potential ${bugs}

# tag easy backportable bugs accordingly in LP
tag $project-easy-proactive-backport-potential ${easy_bugs}

# also create cards in trello
for bug in ${easy_bugs}; do
    if [ $_dry -eq 1 ]; then
        echo "Would import bug $bug as easy backport"
    else
        filch-import bug --id "$bug" -l EasyBackport -l ProactiveBackport --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
    fi
done

for bug in $bugs; do
    if ! containsElement $bug $easy_bugs; then
        if [ $_dry -eq 1 ]; then
            echo "Would import bug $bug as usual backport"
        else
            filch-import bug --id "$bug" -l ProactiveBackport --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
        fi
    fi
done

# finally output the head of the project that we just triaged
echo "Triaged up to: $project_head"
exit 0
