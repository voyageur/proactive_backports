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
