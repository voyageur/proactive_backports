#!/bin/bash

set -e

DRY_RUN=0
TRELLO_EXTRA_LABEL=""
TRELLO_BOARD="test-bc"
TRELLO_COLUMN="Proactive Backports"
SB_TOKEN=""

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

function tag_story () {
    tag=$1
    all_stories=$(echo "${@:2}" | tr " " "\n")
    if [ ${DRY_RUN} -eq 1 ] || [ -e ${SB_TOKEN} ]; then
        for story in $all_stories; do
            echo "Would tag story $story with $tag"
        done
    else
        echo "$all_stories" | "${SCRIPTS_DIR}"/sb-tag.py --token ${SB_TOKEN} "$tag"
    fi
}

function goto {
    proj=$1
    mkdir -p "${GIT_DIR}"
    cd "${GIT_DIR}"
    cd $("${SCRIPTS_DIR}"/os-clone.sh "$proj")
}

function show_help {
    echo "Proactive backports tracker for Storyboard
Usage: $(basename $0) [-d] [-b board] [-c column] [-h] [-l extra_label]
                      [-t sb_token] -p project -s oldest_rev

Options:
-d              dry run, do do not actually do any changes in external sources
-b board        override Trello board to use
-c column       override Trello column to use
-l extra_label  set an additional Trello label
-p project      project to analyze
-s oldest_rev   git revision to start parsing from
-t sb_token     storyboard API token to tag stories"

    exit 0
}

### MAIN ###

while getopts "b:c:dhl:p:s:t:" arg; do
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
        t)
            SB_TOKEN=$OPTARG
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

    # needed to update storyboard
    "${GIT_VENV}"/bin/pip install python-storyboardclient


    "${GIT_VENV}"/bin/pip install git+https://github.com/rbrady/filch.git
fi
. "${GIT_VENV}"/bin/activate

# Stories are prefixed as "storyboard:xxx", filter on the separator
cmd=""${SCRIPTS_DIR}"/bugs-fixed-since.py -sb --repo $project_dir --start $oldest"

# calculate list of easy backports and all backports to be able to tag the
# former separately in trello
stories=`${cmd} | \
      cut -s -d: -f2`

easy_stories=`${cmd} -e | \
      cut -s -d: -f2`

# tag stories as potential backports in SB
tag_story $project-proactive-backport-potential ${stories}

# tag easy backportable stories accordingly in SB
tag_story $project-easy-proactive-backport-potential ${easy_stories}

# also create cards in trello
for story in ${easy_stories}; do
    if [ ${DRY_RUN} -eq 1 ]; then
        echo "Would import story $story as easy backport"
    else
        filch-import story --id "$story" -l EasyBackport -l ProactiveBackport ${TRELLO_EXTRA_LABEL} --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
    fi
done

for story in $stories; do
    if ! containsElement $story $easy_stories; then
        if [ ${DRY_RUN} -eq 1 ]; then
            echo "Would import story $story as usual backport"
        else
            filch-import story --id "$story" -l ProactiveBackport ${TRELLO_EXTRA_LABEL} --list_name="${TRELLO_COLUMN}" -b "${TRELLO_BOARD}"
        fi
    fi
done

# finally output the head of the project that we just triaged
echo "Triaged up to: $project_head"
exit 0
