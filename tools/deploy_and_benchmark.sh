readonly REPO_ROOT_DIR=/home/isucon/private_isu
readonly NGINX_ACCESS_LOG=/var/log/nginx/access.log
readonly NGINX_ERROR_LOG=/var/log/nginx/error.log
readonly MYSQL_SLOW_LOG=/var/log/mysql/mysql-slow.log
readonly RESULT_BASE_DIR=$REPO_ROOT_DIR/result
readonly BENCHMARKER_INSTANCE_PRIVATE_IP=172.31.46.66
readonly APP_INSTANCE_PRIVATE_IP=172.31.43.134
readonly MYSQL_DEPLOY_DIR=$REPO_ROOT_DIR/sql
readonly MYSQL_CONF_DIR=/etc/mysql/mysql.conf.d
readonly NGINX_CONF_DIR=/etc/nginx

if (( $# != 1 )); then
  echo "Usage: $0 <change log>"
  exit 1
else
  readonly changelog=$1
fi

set -ux

# get latest changes
git pull
readonly commit_id=$(git rev-parse HEAD)

# create result dir
readonly dt=$(date +%Y%m%d-%H%M%S)
readonly result_dir=${RESULT_BASE_DIR}/${dt}_${commit_id}
mkdir -p $result_dir

###
# refresh logs
###

# refresh nginx access & error log
sudo truncate --size 0 $NGINX_ACCESS_LOG $NGINX_ERROR_LOG

# refresh mysql slow query log
sudo truncate --size 0 $MYSQL_SLOW_LOG
sudo mysqladmin flush-logs

###
# deploy
###

# deploy mysql
sudo cp ${REPO_ROOT_DIR}/conf/mysql/mysql.cnf $MYSQL_CONF_DIR/
sudo cp ${REPO_ROOT_DIR}/conf/mysql/mysqld.cnf $MYSQL_CONF_DIR/
sudo systemctl restart mysql

for file in $(find $MYSQL_DEPLOY_DIR -type f); do
  mysql --force isuconp < $file
done

# deploy nginx
sudo cp $REPO_ROOT_DIR/conf/nginx/nginx.conf $NGINX_CONF_DIR/
sudo cp $REPO_ROOT_DIR/conf/nginx/isucon.conf $NGINX_CONF_DIR/sites-enabled/
sudo systemctl reload nginx

# deploy go
(
  cd $REPO_ROOT_DIR
  cd webapp/golang
  bash setup.sh
)
sudo systemctl restart isu-go

###
# prepare benchmark
###

# start collectl
readonly collectl_result_dir=$result_dir/collectl
mkdir -p $collectl_result_dir
collectl -scdm -f $collectl_result_dir -P &
readonly collectl_job_id=$!

# start profile
readonly profile_tmp_dir=$(mktemp -d)
curl "http://localhost:80/pprof/start?path=${profile_tmp_dir}/"

###
# run benchmark
###
readonly benchmark_result_dir=$result_dir/benchmark
mkdir -p $benchmark_result_dir
cmd="/home/isucon/private_isu.git/benchmarker/bin/benchmarker -u /home/isucon/private_isu.git/benchmarker/userdata -t http://${APP_INSTANCE_PRIVATE_IP}"
ssh -i ~/.ssh/for_benchmarker isucon@$BENCHMARKER_INSTANCE_PRIVATE_IP $cmd | tee $benchmark_result_dir/benchmarker.log

###
# collect result
###

# stop profile & analyze
curl "http://localhost:80/pprof/stop"
readonly profile_result_dir=$result_dir/profile
mkdir -p $profile_result_dir
go tool pprof --pdf ${profile_tmp_dir}/cpu.pprof > ${profile_result_dir}/prof.pdf

# finish collectl & run colplot
kill -SIGINT $collectl_job_id
colplot -dir $collectl_result_dir -plots cpu,disk,mem -filetype png -filedir $collectl_result_dir -height 0.5 -lastmins 3

# alp
readonly alp_result_dir=$result_dir/alp
mkdir -p $alp_result_dir
sudo alp json --file $NGINX_ACCESS_LOG --sort=sum -r -m "/posts/[0-9]+,/@\w+,/image/\d+" > $alp_result_dir/alp.log

# copy nginx access & error log
readonly nginx_result_dir=$result_dir/nginx
mkdir -p $nginx_result_dir
sudo gzip --best -c $NGINX_ACCESS_LOG > $nginx_result_dir/access.log.gz
sudo gzip --best -c $NGINX_ERROR_LOG > $nginx_result_dir/error.log.gz

# analyze mysql slow query log
readonly mysql_result_dir=$result_dir/mysql
mkdir -p $mysql_result_dir
# sudo mysqldumpslow $MYSQL_SLOW_LOG > $mysql_result_dir/mysqldumpslow.log  # 遅いので後回し
# sudo pt-query-digest $MYSQL_SLOW_LOG > $mysql_result_dir/pt-query-digest.log  # 遅いので後回し
# sudo gzip --best -c $MYSQL_SLOW_LOG > $mysql_result_dir/mysql-slow.log.gz  # 重すぎる

# add summary row
readonly jqout=$(tail -n 1 $benchmark_result_dir/benchmarker.log | jq -r '[.pass,.score,.success,.fail] | @tsv' | tr '\t' '|')
echo "|${dt}|${jqout}|${commit_id}|${changelog}|" >> $RESULT_BASE_DIR/summary.md

# git push
sudo chown -R isucon $result_dir
sudo chgrp -R isucon $result_dir
git add --all
git commit -m "${commit_id}" -m "committed by deploy_and_benchmark.sh"
git push

# 後回しにされた処理を実行
# sudo mysqldumpslow $MYSQL_SLOW_LOG > $mysql_result_dir/mysqldumpslow.log
sudo pt-query-digest $MYSQL_SLOW_LOG > $mysql_result_dir/pt-query-digest.log

sudo chown -R isucon $result_dir
sudo chgrp -R isucon $result_dir
git add --all
git commit -m "${commit_id}" -m "committed by deploy_and_benchmark.sh"
git push
