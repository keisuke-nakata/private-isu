## 最初にやらないといけないこと
- `result` branch を作成してチェックアウト: `git branch result && git checkout result`
  - `result/` ディレクトリを作る: `mkdir result`
  - `result/summary.md` を作る: `echo -e "|dt|score|commit id|change log|\n|--|--|--|--|" > result/summary.md`s
  - `result` branch を push: `git push origin result`
- `result` branch を各サーバに作成しておく: `git checkout -b result --track origin/result && git checkout main`
  - 予めこれをしておかないと、`result` branch がまだローカルにない状態では、 `git checkout result` が失敗する可能性がある (同名のディレクトリがあるとダメらしい)
