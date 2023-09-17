set -eux

source "$(dirname "$0")/config.sh"

node_result_dir=$NODE_RESULT_DIR

###
# collect result
###
mkdir -p $node_result_dir

# stop profile & analyze
curl "http://localhost:${GO_PORT}/api/pprof/stop"
readonly profile_result_dir=$node_result_dir/profile
mkdir -p $profile_result_dir
cp $PPORF_DIR/cpu.pprof ${profile_result_dir}/
go tool pprof --pdf $PPORF_DIR/cpu.pprof > ${profile_result_dir}/prof.pdf

# alp
readonly alp_result_dir=$node_result_dir/alp
mkdir -p $alp_result_dir
sudo alp json --file $NGINX_ACCESS_LOG --sort=sum -r -m ${ALP_PATTERN} > $alp_result_dir/alp.txt

# analyze mysql slow query log
readonly mysql_result_dir=$node_result_dir/mysql
mkdir -p $mysql_result_dir
sudo pt-query-digest $MYSQL_SLOW_LOG > $mysql_result_dir/pt-query-digest.txt
# sudo gzip --best -c $MYSQL_SLOW_LOG > $mysql_result_dir/mysql-slow.log.gz  # 重すぎる

# git push
sudo chown -R isucon $node_result_dir
sudo chgrp -R isucon $node_result_dir
git checkout -b "auto${node_result_dir}"
git add --all
git commit -m "committed by after_bench.sh"
git push -u origin "auto${node_result_dir}"
git checkout main
