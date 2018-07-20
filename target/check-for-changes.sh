#! /bin/bash

# Prevent a start too early
sleep 5

# create date for log output
log_date=$(date +"%Y-%m-%d %H:%M:%S ")

echo "${log_date} Start check-for-changes script."

#pgsql stuff here

if [ ! -v USE_PGSQL_DATABASE ] #note the lack of a $ sigil
then
    echo "USE_PGSQL_DATABASE variable is unset"
elif [ -z "$USE_PGSQL_DATABASE" ]
then
    echo "USE_PGSQL_DATABASE Variable is set to an empty string"
else
    echo "USE_PGSQL_DATABASE Variable is set - setting files"
    #pam section
    echo "auth required pam_pgsql.so" > /etc/pam.d/smtp
    echo "account required pam_pgsql.so" >> /etc/pam.d/smtp
    echo "password required pam_pgsql.so" >> /etc/pam.d/smtp
    #pam_pgsql
    echo "database = ${PGSQL_DATABASE_NAME}" > /etc/pam_pgsql.conf
    echo "user = ${PGSQL_DATABASE_USER}" >> /etc/pam_pgsql.conf
    echo "host = ${PGSQL_DATABASE_HOST}" >> /etc/pam_pgsql.conf
    echo "password = ${PGSQL_DATABASE_PASSWORD}" >> /etc/pam_pgsql.conf
    echo "port = ${PGSQL_DATABASE_PORT}" >> /etc/pam_pgsql.conf
    #for postfix
    echo "dbname = ${PGSQL_DATABASE_NAME}" > /tmp/pgsql.conf
    echo "user = ${PGSQL_DATABASE_USER}" >> /tmp/pgsql.conf
    echo "hosts = ${PGSQL_DATABASE_HOST}:${PGSQL_DATABASE_PORT}" >> /tmp/pgsql.conf
    echo "password = ${PGSQL_DATABASE_PASSWORD}" >> /tmp/pgsql.conf    
    #
    #prepare main.cf
    sed -i '/virtual_/d' /etc/postfix/main.cf
    #cat /tmp/pgsql_virtual_postfix.conf >> /etc/postfix/main.cf
    rm -f /tmp/pgsql_virtual_postfix.conf
    echo "virtual_mailbox_base = /var/mail" >> /etc/postfix/main.cf
    echo "virtual_mailbox_domains = pgsql:/etc/postfix/pgsql_virtual_domains_maps.cf" >> /etc/postfix/main.cf
    echo "virtual_mailbox_maps = pgsql:/etc/postfix/pgsql_virtual_mailbox_maps.cf" >> /etc/postfix/main.cf
    echo "recipient_bcc_maps =  pgsql:/etc/postfix/pgsql_virtual_recipient_bcc_maps.cf" >> /etc/postfix/main.cf
    echo "virtual_mailbox_limit = 5502400000" >> /etc/postfix/main.cf
    echo "virtual_gid_maps = static:5000" >> /etc/postfix/main.cf
    echo "virtual_minimum_uid = 5000" >> /etc/postfix/main.cf
    echo "virtual_uid_maps = static:5000" >> /etc/postfix/main.cf
    echo "virtual_transport = virtual" >> /etc/postfix/main.cf
    #do postgres virtual stuff here
    for filename in /tmp/pgsql_virtual_*; do
	    cat /tmp/pgsql.conf ${filename} > ${filename}.cf
    done
    rm -f /tmp/pgsql.conf
    mv /tmp/pgsql_virtual_*.cf /etc/postfix/ && rm -f /tmp/pgsql_virtual_*
    echo "pw_type=crypt" >> /etc/pam_pgsql.conf
    echo "auth_query=SELECT passwd.password FROM domains LEFT JOIN passwd ON domains.id = passwd.domainid where (passwd.login::text || '@'::text) || domains.name::text = %u" >> /etc/pam_pgsql.conf
    #dovecot
    echo "connect = host=${PGSQL_DATABASE_HOST} port=${PGSQL_DATABASE_PORT} dbname=${PGSQL_DATABASE_NAME} user=${PGSQL_DATABASE_USER} password=${PGSQL_DATABASE_PASSWORD}" >> /etc/dovecot/dovecot-pgsql.conf.ext
    cat /etc/dovecot/dovecot-pgsql.conf.ext >> /etc/dovecot/dovecot-sql.conf.ext
    sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-sql\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/mail_location/s/^/#/' /etc/dovecot/conf.d/10-mail.conf
    echo "mail_location = maildir:/var/mail/%d/%n@%d" >> /etc/dovecot/conf.d/10-mail.conf
    #
    supervisorctl restart dovecot
    supervisorctl restart saslauthd_pam
    supervisorctl restart postfix

while true; do
sleep 2
done

fi


# change directory
cd /tmp/docker-mailserver

# Check postfix-accounts.cf exist else break
if [ ! -f postfix-accounts.cf ]; then
   echo "${log_date} postfix-accounts.cf is missing! This should not run! Exit!"
   exit
fi 

# Update / generate after start
echo "${log_date} Makeing new checksum file."
if [ -f postfix-virtual.cf ]; then
	sha512sum --tag postfix-accounts.cf --tag postfix-virtual.cf > chksum
else
	sha512sum --tag postfix-accounts.cf > chksum
fi
# Run forever
while true; do

# recreate logdate
log_date=$(date +"%Y-%m-%d %H:%M:%S ")

# Get chksum and check it.
chksum=$(sha512sum -c --ignore-missing chksum)
resu_acc=${chksum:21:2}
if [ -f postfix-virtual.cf ]; then
	resu_vir=${chksum:44:2}
else
	resu_vir="OK"
fi

if ! [ $resu_acc = "OK" ] || ! [ $resu_vir = "OK" ]; then
   echo "${log_date} Change detected"
    #regen postfix accounts.
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailserver/postfix-accounts.cf -a "$ENABLE_LDAP" != 1 ]; then
		sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox
		# Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf
		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb
		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf
		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
		grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf | while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
			# User database for dovecot has the following format:
			# user:password:uid:gid:(gecos):home:(shell):extra_fields
			# Example :
			# ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
			echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
			mkdir -p /var/mail/${domain}
			if [ ! -d "/var/mail/${domain}/${user}" ]; then
				maildirmake.dovecot "/var/mail/${domain}/${user}"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
				echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
				touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
			fi
			# Copy user provided sieve file, if present
			test -e /tmp/docker-mailserver/${login}.dovecot.sieve && cp /tmp/docker-mailserver/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp
		done
	fi
	if [ -f postfix-virtual.cf ]; then
    # regen postfix aliases
    echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
		# Copying virtual file
		cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1     other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-virtual.cf
	fi
	if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
		# Copying regexp alias file
		cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ regexp:.*//
		s/$/ regexp:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
	fi
	fi
    # Set vhost 
	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
    
    # Set right new if needed
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		chown -R 5000:5000 /var/mail
	fi
    
    # Restart of the postfix
    supervisorctl restart postfix
    
    # Prevent restart of dovecot when smtp_only=1
    if [ ! $SMTP_ONLY = 1 ]; then
        supervisorctl restart dovecot
    fi 

    echo "${log_date} Update checksum"
	if [ -f postfix-virtual.cf ]; then
    sha512sum --tag postfix-accounts.cf --tag postfix-virtual.cf > chksum
	else
	sha512sum --tag postfix-accounts.cf > chksum
	fi
fi

sleep 1
done
