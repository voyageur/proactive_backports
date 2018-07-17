===========================
Proactive backports scripts
===========================

Configuration
=============

To create Trello cards, you need to configure filch as described at
https://github.com/rbrady/filch#configuration

Options
=======

Run ``backport-tracker-lp-update.sh`` (for Launchpad) or
``backport-tracker-lp-update.sh`` (for Storyboard) with "-h" flag to see
current options.

The script has required options:
 * project to go through (neutron for example) "-p"
 * initial git commit hash with "-s"

There are additional options to set the following elements:
 * Trello board name "-b"
 * Trello column name "-c"
 * Additional label to set when creating cards "-l"
 * (Storyboard only) API token to update stories "-t"

There is also "-d" flag to do a dry run



==============
Helper scripts
==============

bugs-fixed-since.py
-------------------

List Launchpad bugs mentioned in master commit messages starting from a specified commit.

Example::

  ./bugs-fixed-since.py -r ../neutron --start=8.0.0

Use ``--stop`` option to list bugs mentioned in stable branch messages stopping
from a specified commit.

Example::

  ./bugs-fixed-since.py -B -r ../neutron --start=8.0.0 --stop=origin/stable/mitaka

Use ``-B`` option to ignore patches that were already backported into all
stable branches.

Example::

  ./bugs-fixed-since.py -B -r ../neutron --start=8.0.0

Use ``-e`` option to ignore patches that don't apply cleanly to one of stable
branches.

Example::

  ./bugs-fixed-since.py -e -r ../neutron --start=8.0.0

Use ``-sb`` option to also include StoryBoard bugs

Example::

  ./bugs-fixed-since.py -sb -r ../octavia --start=1.0.0


lp-filter-bugs-by-importance.py
-------------------------------

Reads the list of Launchpad bug numbers on stdin and filters out those of
importance specified. Filtering out Wishlist bugs if importance not specified.

Example::

  ./bugs-fixed-since.py [...] --start=8.0.0 | \
  ./lp-filter-bugs-by-importance.py neutron

List bugs that are fixed in master since 8.0.0 that are not of Wishlist
importance.

Example::

  ./bugs-fixed-since.py --start=8.0.0 | \
  ./lp-filter-bugs-by-importance.py neutron | \
  ./lp-filter-bugs-by-importance.py neutron --importance Low

List bugs that are fixed in master since 8.0.0 that are not of Wishlist or Low
importance.


lp-filter-bugs-by-tag.py
------------------------

Reads the list of Launchpad bug numbers on stdin and filters out those with
a tag specified.

Example::

  ./bugs-fixed-since.py [...] --start=8.0.0 | \
  ./lp-filter-bugs-by-tag.py neutron --tag in-stable-mitaka

List bugs that are fixed in master since 8.0.0 that don't have relevant fixes
merged in stable/mitaka.


annotate-lp-bugs.py
-------------------

Reads the list of Launchpad bug numbers on stdin and writes out a nice and
detailed description for each of them.

Example::

  ./bugs-fixed-since.py [...] --start=8.0.0 | ./annotate-lp-bugs.py neutron

Pull in detailed description for bugs that are fixed in master since 8.0.0.


lp-reset-backport-potential.py
------------------------------

Clean up <*>-backport-potential tags for bugs with in-stable-<*> tag set.

Example::

  ./lp-reset-backport-potential.py neutron python-neutronclient


lp-tag.py
---------

Append a tag to bugs specified on stdin.

Example::

  ./bugs-fixed-since.py [...] --start=8.0.0 | ./lp-tag.py foo-tag

This command will add the 'foo-tag' tag to all bugs fixed since 8.0.0.


sb-filter-stories-by-tag.py
---------------------------

Reads the list of StoryBoard story numbers on stdin, filters out stories
matching a tag.

Example::

  ./bugs-fixed-since.py [...] -sb --start=1.0.0 | \
  ./sb-filter-stories-by-tag.py in-stable-pike

List stories fixed in master since 1.0.0 that do not have relevant fixes merged
in stable/pike.


sb-tag.py
---------

Appends a tag to stories specified on stdin.

Example::

  ./bugs-fixed-since.py [...] -sb --start=1.0.0 | \
  ./sb-tag.py foo-tag

This command will add the 'foo-tag' tag to all stories fixed since 1.0.0.

