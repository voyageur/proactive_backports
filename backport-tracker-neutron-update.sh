#!/bin/bash

# !!! The script assumes dbus-python is installed for secretstorage !!!

set -e

DRY_RUN=0
TRELLO_EXTRA_LABEL=""
TRELLO_COLUMN="Proactive Backports"

PROJECT="neutron"
TRELLO_BOARD_VNES="DFG-Networking-vNES Squad"
TRELLO_BOARD_OVN="DFG-Networking-OVN Squad"

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
Usage: $(basename $0) [-d] [-c column] [-h] [-l extra_label] -s oldest_rev

Options:
-d              dry run, do do not actually do any changes in external sources
-c column       override Trello column to use
-l extra_label  set an additional Trello label
-s oldest_rev   git revision to start parsing from"

    exit 0
}

### MAIN ###

while getopts "c:dhl:p:s:" arg; do
    case $arg in
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
        s)
            oldest=$OPTARG
            ;;
    esac
done
shift $((OPTIND-1))

# require start hash specified
[ -n "$oldest" ] || die "start hash not specified"

goto "openstack/${PROJECT}"
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

# All bugs
bug_list=$("${SCRIPTS_DIR}"/bugs-fixed-since.py --repo $project_dir --start $oldest)

# Filter out low importance
bugs=$(echo "${bug_list}" | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py ${PROJECT} --importance Wishlist | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py ${PROJECT} --importance Low | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-importance.py ${PROJECT} --importance Medium)
# Filter out RFEs
bugs=$(echo "${bugs}" | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-tag.py ${PROJECT} rfe | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-tag.py ${PROJECT} rfe-approved)

# Separate list for OVN bugs
filter_ovn_bugs=$(echo "${bugs}" | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-tag.py ${PROJECT} ovn | \
      "${SCRIPTS_DIR}"/lp-filter-bugs-by-tag.py ${PROJECT} ovn-octavia-provider)

# tag bugs as potential backports in LP
tag_lp $PROJECT-proactive-backport-potential ${bugs}

# also create cards in trello
for bug in $bugs; do
    if containsElement ${bug} ${filter_ovn_bugs}; then
        board=${TRELLO_BOARD_VNES}
    else
        board=${TRELLO_BOARD_OVN}
    fi
    if [ ${DRY_RUN} -eq 1 ]; then
        echo "Would import bug ${bug} as backport to ${board}"
    else
        filch-import bug --id "${bug}" -l ProactiveBackport ${TRELLO_EXTRA_LABEL} --list_name="${TRELLO_COLUMN}" -b "${board}"
    fi
done

# finally output the head we just triaged
echo "Triaged up to: $project_head"
exit 0
