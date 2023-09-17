## インスタンス起動

https://github.com/catatsuy/private-isu/blob/master/README.md#ami に記載されている AMI (x86_64) を使って、それぞれ競技用・ベンチマークのインスタンスを起動。
EC2 では
* disk をそれぞれ 16GB 準備
* VPC は、inbound にルールを3つ設定：
  * HTTP を「自宅IP」許可
  * SSH を「自宅IP」許可
  * すべてのトラフィックを「自分自身の VPC」許可

インスタンスが起動したら、ブラウザから http://<public ip> につながるか確認

## ssh config に以下を追記 @local

```ssh-config
Host private-isu
  HostName <public ip>
  User ubuntu
  IdentityFile ~/.ssh/priavate-isu2.pem

Host private-isu-bench
  HostName <public ip for bench>
  User ubuntu
  IdentityFile ~/.ssh/private-isu2.pem
```

これで、 `ssh private-isu` でインスタンスにつながる

## git setup @contest (contest: 競技用インスタンスの意)

github.com に空の repository を作っておく

```bash
sudo su - isucon

# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key-for-a-hardware-security-key を参考に ssh key (deploy key として使う) を生成。passphrase なし
ssh-keygen -t ed25519-sk -C "private-isu"

# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#set-up-deploy-keys を参考に↑の鍵を deploy key として追加
# 具体的には、repository の Settings -> deploy keys -> Add を押して、 `cat ~/.ssh/id_ed25519.pub` の結果を貼り付ける

cd /home/isucon/private_isu
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin git@github.com:keisuke-nakata/private-isu.git
git push origin main
```

## first benchmark @bench

https://github.com/catatsuy/private-isu/blob/master/README.md#ami の「ベンチマーカー用インスタンスのベンチマーカー実行方法」をそのまま実行する

```console
$ sudo su - isucon
$ /home/isucon/private_isu.git/benchmarker/bin/benchmarker -u /home/isucon/private_isu.git/benchmarker/userdata -t http://<target IP>
{"pass":true,"score":577,"success":554,"fail":3,"messages":["リクエストがタイムアウトしました (POST /login)","リクエストがタイムアウトしました (POST /register)"]}
```

## go 実装に切り替え @contest

https://github.com/catatsuy/private-isu/blob/master/manual.md#go%E3%81%B8%E3%81%AE%E5%88%87%E3%82%8A%E6%9B%BF%E3%81%88%E6%96%B9

```bash
sudo systemctl stop isu-ruby
sudo systemctl disable isu-ruby
sudo systemctl start isu-go
sudo systemctl enable isu-go
```

もう一度ブラウザ疎通とベンチーマーク実施して問題ないことを確認。
(なんかスコアがゼロになってしまっているけど、何回か success はしているので、とりあえず気にしない)

```
{"pass":true,"score":0,"success":204,"fail":62,"messages":["リクエストがタイムアウトしました (GET /)","リクエストがタイムアウトしました (GET /@amy)","リクエストがタイムアウトしました (GET /@briana)","リクエストがタイムアウトしました (GET /@flora)","リクエストがタイムアウトしました (GET /@georgette)","リクエストがタイムアウトしました (GET /@marguerite)","リクエストがタイムアウトしました (GET /@ronda)","リクエストがタイムアウトしました (GET /@stefanie)","リクエストがタイムアウトしました (GET /@stephanie)","リクエストがタイムアウトしました (POST /login)","リクエストがタイムアウトしました (POST /register)"]}
```

build が通るかを確認:

適当に log.Print("hello, first build!") などを main に追記してから、

```console
$ make
go build -o app
$ sudo systemctl restart isu-go
$ sudo journalctl -u isu-go
...
Sep 17 12:55:51 ip-172-31-29-99 app[6908]: 2023/09/17 12:55:51 app.go:795: hello, first build!
```

## profiler を仕込む @contest

対応する場所に以下を仕込む。

### "github.com/go-chi/chi/v5" の場合:

```go
import (
	...
	"github.com/pkg/profile"
)

...

var profiler interface{ Stop() }

...

	// pprof
	r.Get("/api/pprof/start", getProfileStart)
	r.Get("/api/pprof/stop", getProfileStop)

...

func getProfileStart(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	profiler = profile.Start(profile.ProfilePath(path))
	w.WriteHeader(http.StatusOK)
}

func getProfileStop(w http.ResponseWriter, r *http.Request) {
	profiler.Stop()
	w.WriteHeader(http.StatusOK)
}
```

### "github.com/labstack/echo/v4" の場合

```go
import (
	...
	"github.com/pkg/profile"
)
...

var profiler interface{ Stop() }

...

	// pprof
	e.GET("/api/pprof/start", getProfileStart)
	e.GET("/api/pprof/stop", getProfileStop)

...

func getProfileStart(c echo.Context) error {
	path := c.QueryParam("path")
	profiler = profile.Start(profile.ProfilePath(path))
	return c.JSON(http.StatusOK, "pprof start ok")
}

func getProfileStop(c echo.Context) error {
	profiler.Stop()
	return c.JSON(http.StatusOK, "pprof stop ok")
}
```

### チェック

```console
$ go get github.com/pkg/profile
$ make 
$ sudo systemctl restart isu-go
$ mkdir /home/isucon/pprof
$ curl "http://localhost:8080/api/pprof/start?path=/home/isucon/pprof/"
# ここで適当にアプリにアクセスして、profile を取得
$ curl "http://localhost:8080/api/pprof/stop"
$ sudo apt install graphviz
$ go tool pprof --pdf /home/isucon/pprof/cpu.pprof > /home/isucon/pprof/prof.pdf
```

## ツールのインストール @contest

```bash
# alp
wget https://github.com/tkuchiki/alp/releases/download/v1.0.16/alp_linux_amd64.tar.gz
tar -zxvf alp_linux_amd64.tar.gz
sudo install alp /usr/local/bin/alp

# pt-query-digest
sudo apt update
sudo apt install percona-toolkit
```

## bench.sh, before_bench.sh, after_bench.sh, config.sh を追加して中身の設定を行う

config.sh に合わせて以下を調整 (もしくはスクリプト側を修正):

### mysql 関連
- `MYSQL_CONF_SRC=$CONF_DIR/sql/mysqld.cnf` を、 `MYSQL_CONF_DEST=/etc/mysql/mysql.conf.d/mysqld.cnf` からコピーして作成
- 以下の設定を足す:

```conf
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 0
```

### nginx 関連
- `NGINX_ROOT_CONF_SRC=$CONF_DIR/nginx/nginx.conf` を、 `NGINX_ROOT_CONF_DEST=/etc/nginx/nginx.conf` からコピーして作成
- 以下の設定を足す：

```nginx-conf
http {
    ...
    log_format json escape=json '{"time":"$time_iso8601",'
                                '"host":"$remote_addr",'
                                '"port":$remote_port,'
                                '"method":"$request_method",'
                                '"uri":"$request_uri",'
                                '"status":"$status",'
                                '"body_bytes":$body_bytes_sent,'
                                '"referer":"$http_referer",'
                                '"ua":"$http_user_agent",'
                                '"request_time":"$request_time",'
                                '"response_time":"$upstream_response_time"}';
    access_log /var/log/nginx/access.log json;
    ...
}
```

- `NGINX_SITE_CONF_SRC=$CONF_DIR/nginx/isucon.conf` を、 `NGINX_SITE_CONF_DEST=/etc/nginx/sites-available/isucon.conf` からコピーして作成

### result 関連
```bash
$ mkdir result
$ echo "|dt|score|commit id|change log|
|--|--|--|--|" > result/summary.md
```
