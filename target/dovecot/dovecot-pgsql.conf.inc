driver = pgsql
connect = host=localhost dbname=mails user=mailreader password=secret
default_pass_scheme = CRYPT
password_query = SELECT passwd.password as password,  passwd.login::text || '@'::text || domains.name::text as user FROM domains LEFT JOIN passwd ON domains.id = passwd.domainid where passwd.login::text || '@'::text || domains.name::text  = %u
user_query = SELECT '/var/mail/'||domains.name::text ||'/'|| passwd.login::text || '@'::text || domains.name::text as home, 5000 as gid, 5000 as uid FROM domains LEFT JOIN passwd ON domains.id = passwd.domainid where passwd.login::text || '@'::text || domains.name::text = '%u'