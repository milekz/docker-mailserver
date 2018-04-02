#!/bin/bash
#auto subscriptions for dovecot run in dir contain mailboxes
for filename in */; do
    echo doing - $filename
    cd $filename
    ls -1 -d -A .*| tail -n +3 | cut -c 2- > subscriptions
    chown 5000:5000 subscriptions
    cd ..
done
