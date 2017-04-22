#!/bin/sh

for dir in $HOME $HOME/.ansible-books $HOME/vagrant; do
    pushd $dir 1> /dev/null
    diff=$(git diff HEAD..)
    if [ -n "$diff" ]; then
        echo "Uncommitted changes in $dir:"
    fi
    popd 1> /dev/null
done
