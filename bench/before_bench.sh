set -eux

source "$(dirname "$0")/config.sh"

###
# refresh logs
###

# refresh nginx access & error log
sudo truncate --size 0 $NGINX_ACCESS_LOG $NGINX_ERROR_LOG

# refresh mysql slow query log
sudo truncate --size 0 $MYSQL_SLOW_LOG
# sudo mysqladmin flush-logs

###
# deploy
###

# deploy env.sh
# cp ${REPO_ROOT_DIR}/conf/env.sh /home/isucon/

# deploy mysql
sudo cp $MYSQL_CONF_SRC $MYSQL_CONF_DEST
sudo systemctl restart mysql

# # deploy memcached
# sudo cp $MEMCACHED_CONF_SRC $MEMCACHED_CONF_DEST
# sudo systemctl restart memcached

# deploy nginx
sudo cp $NGINX_ROOT_CONF_SRC $NGINX_ROOT_CONF_DEST
sudo cp $NGINX_SITE_CONF_SRC $NGINX_SITE_CONF_DEST
sudo systemctl reload nginx

# deploy go
(
  cd $REPO_ROOT_DIR/webapp/golang
  make
)
sudo systemctl restart isu-go

###
# prepare benchmark
###

# start profile
sleep 15
mkdir -p ${PPORF_DIR}
curl "http://localhost:${GO_PORT}/api/pprof/start?path=${PPORF_DIR}/"
