
passdb {
  driver = pgsql
  args = /etc/dovecot/dovecot-pgsql.conf.inc
}

userdb {
  driver = pgsql
  args = /etc/dovecot/dovecot-pgsql.conf.inc
}
