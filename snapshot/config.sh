readonly RELEASE_BRANCH=main
readonly RESULT_BRANCH=result

readonly APPSERVER1_PRIVATE_IP=192.168.0.11
# readonly APPSERVER2_PRIVATE_IP=192.168.0.12
# readonly APPSERVER3_PRIVATE_IP=192.168.0.13

readonly REPO_ROOT_DIR=/home/isucon/private_isu
readonly SNAPSHOT_SCRIPT_DIR=$REPO_ROOT_DIR/snapshot
readonly CONF_DIR=$REPO_ROOT_DIR/conf
readonly MYSQL_CONF_SRC=$CONF_DIR/sql/mysqld.cnf
readonly NGINX_ROOT_CONF_SRC=$CONF_DIR/nginx/nginx.conf
readonly NGINX_SITE_CONF_SRC=$CONF_DIR/nginx/isucon.conf
# readonly MEMCACHED_CONF_SRC=$CONF_DIR/memcached/memcached.conf
readonly RESULT_BASE_DIR=$REPO_ROOT_DIR/result

readonly NGINX_ACCESS_LOG=/var/log/nginx/access.log
readonly NGINX_ERROR_LOG=/var/log/nginx/error.log
readonly MYSQL_SLOW_LOG=/var/log/mysql/mysql-slow.log
readonly MYSQL_CONF_DEST=/etc/mysql/mysql.conf.d/mysqld.cnf
readonly NGINX_ROOT_CONF_DEST=/etc/nginx/nginx.conf
readonly NGINX_SITE_CONF_DEST=/etc/nginx/sites-available/isucon.conf
# readonly MEMCACHED_CONF_DEST=/etc/memcached.conf

readonly PPORF_DIR=/home/isucon/pprof
readonly GO_PORT=8080
readonly ALP_PATTERN="/image/[0-9]+,/posts/[0-9]+,/@\w+"
