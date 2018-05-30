===========================
Proactive backports scripts
===========================

Configuration
=============

To create Trello cards, you need to configure filch as described at
https://github.com/rbrady/filch#configuration

Options
=======

Run ``backport-tracker-update.sh`` with "-h" flag to see current options.

The script has required options:
 * project to go through (neutron for example) "-p"
 * initial git commit hash with "-s"

There are additional options to set the following elements:
 * Trello board name "-b"
 * Trello column name "-c"
 * Additional label to set when creating cards "-l"

There is also "-d" flag to do a dry run
