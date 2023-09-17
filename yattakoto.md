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

## git setup @競技用インスタンス

github.com に空の repository を作っておく

```console
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
