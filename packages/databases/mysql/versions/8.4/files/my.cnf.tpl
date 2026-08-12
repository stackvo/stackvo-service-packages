# MySQL 8.4 — `skip-character-set-client-handshake` is gone from this file and
# from the compose command, and it was measured against a running container
# rather than read about: 8.4.11 exits 1 with
#
#   [ERROR] [MY-000068] [Server] unknown option
#           '--skip-character-set-client-handshake'
#   [ERROR] [MY-010119] [Server] Aborting
#
# The 9.x directories carry the same removal with the note "removed in 9.0".
# That attribution is wrong by one release — it is already gone in 8.4 — and
# this file is the version that proves it. The symptom is a container in a
# restart loop and an instance the app reports as enabled and not running, so
# it costs a while to find: the fatal line is the last of forty, under a
# `mysql.plugin doesn't exist` that looks more like the cause and is not.
###################################################################
# STACKVO MYSQL DEFAULT CONFIG (my.cnf)
###################################################################

[mysqld]
user=mysql
pid-file=/var/run/mysqld/mysqld.pid
socket=/var/run/mysqld/mysqld.sock

# Performance
innodb_buffer_pool_size=512M
innodb_log_file_size=256M
innodb_flush_method=O_DIRECT
innodb_flush_log_at_trx_commit=1
max_connections=200
thread_cache_size=50

# Character Set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
init-connect='SET NAMES utf8mb4'
# skip-character-set-client-handshake

# Logging
slow_query_log=1
long_query_time=2
slow_query_log_file=/var/log/mysql/slow.log

# General logs (disabled by default)
general_log=0
general_log_file=/var/log/mysql/general.log

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
