# Lambda Blue/Green デプロイ 手順書(RUNBOOK)

設計・計画は [docs/PLAN.md](./PLAN.md) を参照。本書は実際にコマンドを実行する際の手順書。
以下は ap-northeast-1 で `lambda-blue-green-deploy` スタック・関数名 `lambda-blue-green-demo` を使って
実際に一通り検証した際の記録ベースの手順。

## 前提

- AWS CLI / AWS SAM CLIがインストールされていること
- 対象のAWSアカウントに対して有効な認証情報(SSOプロファイル等)が設定されていること
  - 確認: `aws sts get-caller-identity --profile <profile>`
  - 未設定の場合は `aws configure` または `aws sso login --profile <profile>` で設定する
- 以降のコマンド例では `AWS_PROFILE` 環境変数でプロファイルを指定する想定(例: `AWS_PROFILE=takyafumin`)
- `scripts/*.sh` はいずれも `--region` を指定せず、プロファイルに設定されたデフォルトリージョンに依存する。
  本書のコマンド例はすべて `ap-northeast-1` を前提にしているため、使用するプロファイルの
  デフォルトリージョンが `ap-northeast-1` になっていることを事前に確認する(`aws configure get region --profile <profile>`)。
  異なるリージョンがデフォルトになっている場合は `AWS_DEFAULT_REGION=ap-northeast-1` を併せて指定する

## 1. 初回構築

スタックをまだ作成していない場合、初回のみ以下を実行する。

```bash
sam build
AWS_PROFILE=<profile> sam deploy \
  --stack-name lambda-blue-green-deploy \
  --resolve-s3 \
  --region ap-northeast-1 \
  --capabilities CAPABILITY_IAM
```

- `--capabilities CAPABILITY_IAM` が必要(Lambda実行ロールをCloudFormationが作成するため)
- 初回は `samconfig.toml` が無い状態なので、上記のように明示的にオプションを指定するか
  `sam deploy --guided` で対話的に設定する(後者は `samconfig.toml` を生成し、リポジトリには含めない)
- 完了すると出力に関数名(`FunctionName`)が表示される。以降のコマンドではこの関数名を使う

続けて最初のバージョン(blue=v1)を発行し、`live` エイリアスを作成する。

```bash
AWS_PROFILE=<profile> scripts/publish-version.sh lambda-blue-green-demo
# 出力されたVersion番号(例: 1)を使ってエイリアスを作成
AWS_PROFILE=<profile> scripts/create-alias.sh 1 live lambda-blue-green-demo

# 動作確認
AWS_PROFILE=<profile> scripts/invoke-version.sh live '{}' lambda-blue-green-demo
```

## 2. 通常のデプロイ〜検証〜切替フロー(2回目以降)

### 2-1. コードを変更してデプロイする($LATESTの更新。liveには影響しない)

```bash
AWS_PROFILE=<profile> scripts/deploy.sh
```

- `scripts/deploy.sh` は `sam build && sam deploy` を固定で実行するだけで、追加の引数を
  `sam deploy` に渡すことはできない。`samconfig.toml` が無い場合(初回構築で `--guided` を
  使わなかった場合)は、このスクリプトではなく「1. 初回構築」に記載した `sam deploy` の
  コマンドをオプション付きで直接実行する
- この時点では `live` エイリアスも既存のVersionも変化しない。本番(live経由)は旧バージョンのまま動き続ける

### 2-2. 新バージョン(green)を発行する

```bash
AWS_PROFILE=<profile> scripts/publish-version.sh lambda-blue-green-demo
```

出力された新しいVersion番号(例: 2)を以降の手順で使う。

### 2-3. greenを直接invokeして検証する(本番ルーティングを経由しない)

```bash
AWS_PROFILE=<profile> scripts/invoke-version.sh 2 '{}' lambda-blue-green-demo
```

- 併せて `live` 経由でも呼び出し、まだ旧バージョンが応答することを確認しておくと良い
  ```bash
  AWS_PROFILE=<profile> scripts/invoke-version.sh live '{}' lambda-blue-green-demo
  AWS_PROFILE=<profile> scripts/show-alias.sh live lambda-blue-green-demo
  ```

### 2-4. 問題なければエイリアスを切り替える

```bash
AWS_PROFILE=<profile> scripts/switch-alias.sh 2 live lambda-blue-green-demo
```

切替はLambdaのコントロールプレーン上でアトミックに反映される。切替前後でリクエストを継続的に送っても、
エラーや欠落なく旧バージョン→新バージョンへ切り替わることを確認済み(docs/PLAN.mdの「エイリアス切替時の挙動」参照)。

### 2-5. 問題が見つかった場合はロールバックする

```bash
# 例: greenのVersionが2、blueのVersionが1だった場合
AWS_PROFILE=<profile> scripts/switch-alias.sh 1 live lambda-blue-green-demo
```

`switch-alias.sh` は切替とロールバックで同じ操作(エイリアスの向き先変更)なので、
戻したいVersion番号を指定するだけで良い。ロールバック後も `invoke-version.sh live ...` で
期待するVersionが応答することを確認する。

## 3. 状態確認

`live` エイリアスが現在どのVersionを指しているかはいつでも確認できる。

```bash
AWS_PROFILE=<profile> scripts/show-alias.sh live lambda-blue-green-demo
```

## 4. 後片付け

検証用スタックが不要になった場合はCloudFormationスタックを削除する。

```bash
AWS_PROFILE=<profile> aws cloudformation delete-stack --stack-name lambda-blue-green-deploy --region ap-northeast-1
```

- `live` エイリアスはSAM(CloudFormation)管理外だが、Lambda関数自体がスタック削除で削除されるため、
  エイリアス・Versionも関数と一緒に削除される(個別に削除する手順は不要)
- スタックを再作成した場合、`live` エイリアスはCLI管理のため自動では復元されない。
  「1. 初回構築」の手順をやり直してエイリアスを再作成する必要がある(docs/PLAN.mdの
  「エイリアスの状態管理について」参照)
- SAMが管理用に作成したS3バケット(`aws-sam-cli-managed-default-samclisourcebucket-*`)は
  他のSAMプロジェクトと共用されることがあるため、本検証のスタック削除だけでは削除されない。
  不要であれば別途確認の上で削除する
- Lambdaが自動作成するCloudWatch Logsのロググループ(`/aws/lambda/lambda-blue-green-demo`)は
  `template.yaml` で管理していない(CloudFormationリソースとして定義していない)ため、
  スタック削除時には削除されない。完全に片付けたい場合は別途削除する
  ```bash
  AWS_PROFILE=<profile> aws logs delete-log-group --log-group-name /aws/lambda/lambda-blue-green-demo --region ap-northeast-1
  ```
