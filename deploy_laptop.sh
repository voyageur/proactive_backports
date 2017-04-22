#!/bin/sh

set -e

cd ~/.ansible-books
ansible-playbook -K laptop.yml
