#!/bin/bash
#auto subscriptions for dovecot run in dir contain mailboxes
for dname in */; do
    echo doing domain $dname
    cd $dname
        for filename in */; do
	        echo doing account - $filename
	        cd $filename
	        ls -1 -d -A .*| tail -n +3 | cut -c 2- > subscriptions
	        chown 5000:5000 subscriptions
	        cd ..
	      done
    cd ..
done
