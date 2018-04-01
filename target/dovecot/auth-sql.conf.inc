# Authentication for SQL users. Included from 10-auth.conf.
#
# <doc/wiki/AuthDatabase.SQL.txt>

passdb {
  driver = pgsql

  # Path for SQL configuration file, see example-config/dovecot-sql.conf.ext
  args = /etc/dovecot/dovecot-sql.conf.inc
}

userdb {
  driver = pgsql
  args = /etc/dovecot/dovecot-sql.conf.inc
}
