if [[ $# -ne 2 ]]; then
	echo "Usage: $0 <change log> <branch name>"
	exit 1
fi
readonly changelog=$1
readonly branch=$2

source "$(dirname "$0")/config.sh"

set -eux

# prepare
pushd "${REPO_ROOT_DIR}"
readonly old_working_branch=$(git branch --show-current)
git fetch origin
git checkout "${branch}"
git pull origin "${branch}"

readonly commit_id=$(git rev-parse HEAD)

# create result dir
readonly dt=$(date +%Y%m%d-%H%M%S)
readonly result_dir=${RESULT_BASE_DIR}/${dt}_${commit_id}
mkdir -p $result_dir

readonly SSH="ssh -o StrictHostKeyChecking=no"

###
# run before_snapshot.sh
###
cmd="bash ${SNAPSHOT_SCRIPT_DIR}/before_snapshot.sh ${branch}"
# appserver 1 (this)
set +x
bash -c "$cmd"
set -x
# # appserver 2
# set +x
# echo "========================== BEGIN appserver2 =========================="
# $SSH $APPSERVER2_PRIVATE_IP $cmd
# echo "========================== END appserver2 =========================="
# set -x
# # appserver 3
# set +x
# echo "========================== BEGIN appserver3 =========================="
# $SSH $APPSERVER3_PRIVATE_IP $cmd
# echo "========================== END appserver3 =========================="
# set -x

###
# run benchmark
###
echo "Run benchmark, and input your score: "
read score

###
# record score
###
# result branch に最新の main branch をマージ
git fetch origin
git checkout "${RESULT_BRANCH}"
git merge --no-edit "remotes/origin/${RELEASE_BRANCH}"  # aaa
# git merge --no-ff "remotes/origin/${RELEASE_BRANCH}"
# 実行対象が main ブランチである場合のみ、result ブランチで summary.md に記録。それ以外のブランチだとコンフリクトが発生するため何もしない
if [[ "${branch}" == "${RELEASE_BRANCH}" ]]; then
	git checkout "${RESULT_BRANCH}"
	echo "|${dt}|${score}|${commit_id}|${changelog}|" >>$RESULT_BASE_DIR/summary.md
	git add --all
	git commit -m "${commit_id}" -m "committed by snapshot.sh"
	git push origin "${RESULT_BRANCH}" # after snapshot は非常に重いので summay だけ先に push
fi
git checkout "${branch}"

###
# run after_snapshot.sh
###
# appserver 1 (this)
node_result_dir=${result_dir}/appserver1
cmd="bash ${SNAPSHOT_SCRIPT_DIR}/after_snapshot.sh ${node_result_dir} ${branch}"
set +x
bash -c "$cmd"
set -x
git checkout "${RESULT_BRANCH}"
git merge --no-edit "remotes/origin/auto${node_result_dir}"
# # appserver 2
# node_result_dir=${result_dir}/appserver2
# cmd="bash ${SNAPSHOT_SCRIPT_DIR}/after_snapshot.sh ${node_result_dir} ${branch}"
# set +x
# echo "========================== BEGIN appserver2 =========================="
# $SSH $APPSERVER2_PRIVATE_IP $cmd
# echo "========================== END appserver2 =========================="
# set -x
# git checkout "${RESULT_BRANCH}"
# git fetch origin
# git merge --no-edit "remotes/origin/auto${node_result_dir}"
# # appserver 3
# node_result_dir=${result_dir}/appserver3
# cmd="bash ${SNAPSHOT_SCRIPT_DIR}/after_snapshot.sh ${node_result_dir} ${branch}"
# set +x
# echo "========================== BEGIN appserver3 =========================="
# $SSH $APPSERVER3_PRIVATE_IP $cmd
# echo "========================== END appserver3 =========================="
# set -x
# git checkout "${RESULT_BRANCH}"
# git fetch origin
# git merge --no-edit "remotes/origin/auto${node_result_dir}"

# push the result
git push origin "${RESULT_BRANCH}"

# cleanup
git checkout "${old_working_branch}"
popd
