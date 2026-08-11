# MySQL 9.x — two directives are gone from this file and one from the compose
# command, and each was measured against a running container rather than read
# about:
#
#   innodb_log_file_size            removed after 8.0.30 (innodb_redo_log_capacity)
#   skip-character-set-client-handshake  removed in 9.0
#
# Either one makes mysqld exit 1 on first boot with "unknown variable" and
# "The designated data directory is unusable", so a workspace that picked 9.4
# got a container that never started. This is the difference a directory per
# version exists for.
###################################################################
# STACKVO MYSQL DEFAULT CONFIG (my.cnf)
###################################################################

[mysqld]
user=mysql
pid-file=/var/run/mysqld/mysqld.pid
socket=/var/run/mysqld/mysqld.sock

# Performance
innodb_buffer_pool_size=512M
# innodb_log_file_size=256M
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
