#!/bin/bash

# !!! The script assumes dbus-python is installed for secretstorage !!!

set -e

DRY_RUN=0
TRELLO_EXTRA_LABEL=""
TRELLO_BOARD="test-bc"
TRELLO_COLUMN="Proactive Backports"

GIT_DIR="/tmp/proactive-backports"
GIT_VENV="${GIT_DIR}/venv"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function die() { echo "$@" 1>&2 ; exit 1; }

function containsElement () {
    local e
    for e in "${@:2}"; do
        [[ "$e" == "$1" ]] && return 0;
    done
    return 1
}

function tag_lp () {
    tag=$1
    all_bugs=$(echo "${@:2}" | tr " " "\n")
    if [ ${DRY_RUN} -eq 1 ]; then
        for bug in $all_bugs; do
            echo "Would tag bug $bug with $tag"
        done
    else
        echo "$all_bugs" | "${SCRIPTS_DIR}"/lp-tag.py "$tag"
    fi
}

function goto {
    proj=$1
    mkdir -p "${GIT_DIR}"
    cd "${GIT_DIR}"
    cd $("${SCRIPTS_DIR}"/os-clone.sh "$proj")
}

function show_help {
    echo "Proactive backports tracker for Launchpad
Usage: $(basename $0) [-d] [-b board] [-c column] [-h] [-l extra_label] -p project -s oldest_rev

Options:
-d              dry run, do do not actually do any changes in external sources
-b board        override Trello board to use
-c column       override Trello column to use
-l extra_label  set an additional Trello label
-p project      project to analyze
-s oldest_rev   git revision to start parsing from"

    exit 0
}

### MAIN ###

while getopts "b:c:dhl:p:s:" arg; do
    case $arg in
        b)
            TRELLO_BOARD="$OPTARG"
            ;;
        c)
            TRELLO_COLUMN="$OPTARG"
            ;;
        d)
            DRY_RUN=1
            ;;
        h)
            show_help
            ;;
        l)
            TRELLO_EXTRA_LABEL="-l $OPTARG"
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

if ! [ -d "${GIT_VENV}" ]; then
    # dbus-python doesn't work from pypi, so
    # we need to rely on system package here
    virtualenv --system-site-packages "${GIT_VENV}"
    "${GIT_VENV}"/bin/pip install GitPython

    # needed to access launchpad
    "${GIT_VENV}"/bin/pip install launchpadlib secretstorage


    # Local checkout until https://github.com/rbrady/filch/pull/22 merges
    #"${GIT_VENV}"/bin/pip install git+https://github.com/rbrady/filch.git
    "${GIT_VENV}"/bin/pip install git+https://github.com/voyageur/filch.git@fix_storyboard_url
fi
. "${GIT_VENV}"/bin/activate

cmd=""${SCRIPTS_DIR}"/bugs-fixed-since.py --repo $project_dir --start $oldest"

# calculate list of easy backports and all backports to be able to tag the
# former separately in trello
bugs=`${cmd} | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Wishlist | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Low | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Medium`

easy_bugs=`${cmd} -e | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Wishlist | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Low | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py $project --importance Medium`

# tag bugs as potential backports in LP
tag_lp $project-proactive-backport-potential ${bugs}

# tag easy backportable bugs accordingly in LP
tag_lp $project-easy-proactive-backport-potential ${easy_bugs}

# also create cards in trello
for bug in ${easy_bugs}; do
    if [ ${DRY_RUN} -eq 1 ]; then
        echo "Would import bug $bug as easy backport"
    else
        filch-import bug --id "$bug" -l EasyBackport -l ProactiveBackport ${TRELLO_EXTRA_LABEL} --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
    fi
done

for bug in $bugs; do
    if ! containsElement $bug $easy_bugs; then
        if [ ${DRY_RUN} -eq 1 ]; then
            echo "Would import bug $bug as usual backport"
        else
            filch-import bug --id "$bug" -l ProactiveBackport ${TRELLO_EXTRA_LABEL} --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
        fi
    fi
done

# finally output the head of the project that we just triaged
echo "Triaged up to: $project_head"
exit 0
