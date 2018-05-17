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


########
#alternative
#find "/var/mail/virtual/" -name courierimapsubscribed -print0 |  xargs -0r rename -v 's/courierimapsubscribed/subscriptions/'
#find "/var/mail/virtual/" -name subscriptions -print0 | xargs -0r sed -i 's/INBOX\.//'
#find "/var/mail/virtual/" -name courierimapuiddb -print0 |  xargs -0r rename -v 's/courierimapuiddb/dovecot-uidlist/'
#find "/var/mail/virtual/" -name courierimaphieracl -print0 | xargs -0r rm -vrf
#find "/var/mail/virtual/" -name courierimapacl -print0 | xargs -0r rm -vf
#find "/var/mail/virtual/" -name courierimapkeywords -print0 | xargs -0r rm -vrf
#chown -R vmail:vmail "/var/mail/virtual" 

