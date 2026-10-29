# Typle for Mac（SwiftUI）

Typle の macOS 版です。Web 版と同じ画面・判定・記録・ベストの規則で、Mac のキーボードで練習できます。アカウントの保存先は、Web 版・iPad 版・Android 版・Windows 版と同じ Go のバックエンド（本番の `/api/auth/*`・`/api/workspace`）です。

Web 版・iPad 版・バックエンドは [Sparklingstadt/typle-r](https://github.com/Sparklingstadt/typle-r) に、Android 版は [Sparklingstadt/typle-a](https://github.com/Sparklingstadt/typle-a)、Windows 版は [Sparklingstadt/typle-w](https://github.com/Sparklingstadt/typle-w) にあります。Mac 版はもともと typle-r の `macos/` にあり、iPad 版（`ios/Typle`）の SwiftUI のコードと共通の規則（`ios/TypleCore`）をそのまま使っていました。typle-r v0.88.0 でこのリポジトリに分け、そのとき（typle-r v0.86.1）の iPad 版のコードを `Shared/`、共通の規則を `TypleCore/` に写しました。履歴は typle-r の `macos/`・`ios/Typle`・`ios/TypleCore` の履歴を引き継いでいます（コミットの `(Sparklingstadt/typle-r#123)` は typle-r の PR です）。

これからは iPad 版で直したことは自動では入りません。必要なものは、このリポジトリで同じように直します。コードのコメントにある `src/…` は typle-r の Web 版のファイルです。

## 必要なもの

- macOS 14（Sonoma）以上の Mac
- ビルドするとき: Xcode 16 以上と [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

## 入れ方

1. `Typle-macOS.zip` を開いて、`Typle.app` を「アプリケーション」に移します。
2. Apple の公証（notarization）を受けていないため、初回は Finder で `Typle.app` を Control キーを押しながらクリックして「開く」を選びます（macOS 15 以降は、一度開こうとした後で「システム設定」→「プライバシーとセキュリティ」の「このまま開く」）。
3. ターミナルで `xattr -dr com.apple.quarantine /Applications/Typle.app` を実行しても開けるようになります。

App Store には出していません。

自分でビルドするときは次のとおりです。

```sh
xcodegen generate      # project.yml から Typle.xcodeproj を作る（コミットしない）
open Typle.xcodeproj
```

実行先を「My Mac」にして ⌘R で実行します。署名は「Sign to Run Locally」（アドホック署名）にしてあるので、Team を選ばなくても起動できます。自分の証明書で署名したいときは、「Signing & Capabilities」で Team を選びます。

typle-r の iPad 版のプロジェクト（`ios/Typle.xcodeproj`）を「My Mac (Designed for iPad)」で動かしたものは Mac 版ではありません（Team も要ります）。

## 見た目と操作

Web 版と同じ画面構成・色・部品です。上部バー（ブランド・保存先・ライト／ダーク・アカウント）、ウインドウの幅が 1280pt 以上ならサイドバー、それより狭ければメニューボタンで開くドロワー。色と角丸は Web 版の `src/app/globals.css` の値（`Shared/Design/Theme.swift`）です。

| 操作 | 内容 |
|---|---|
| ⌘1〜⌘6 | メニューの「移動」から、ホーム・練習する・練習記録・ベスト記録・単語リスト・端末へ |
| ⌘N | リストを作成 |
| ⌘, | 一般（表示言語・保存先・ログイン） |
| Esc | 練習のやり直し |
| Return | 結果画面でもう一度 |
| ⌘Return | 単語リストの編集で保存 |
| 任意のキー | 練習欄の外をクリックした後、練習欄に戻る（Web 版と同じく、そのキーは入力しません） |

- 練習欄は AppKit の `NSTextField` で、自動修正・スペルチェック・自動置換・入力候補（インライン予測）・取り消し・ペースト・ドロップを使えません。変換中（日本語・中国語の入力など）の文字は判定せず、確定した文字だけを判定します。
- 単語リストの「CSV で書き出す」は、保存先を選ぶ画面で書き出します（iPad は共有シート）。取り込みはファイルを選ぶ画面から行います。
- ガイド・Typleについては、メニューの「ヘルプ」とサイドバーから Web 版を開きます。

## 保存先

| 保存先 | 内容 |
|---|---|
| この Mac（既定） | アプリのコンテナーの Application Support の `workspace.json`。形は Web 版のブラウザー保存と同じです。読めないファイルは上書きしません |
| アカウント（GitHub） | Web 版の Typle（既定は本番の `https://typle-r-six.vercel.app`）に GitHub でログインし、Web 版と同じアカウントの単語リスト・記録・端末を、Go のバックエンドの `/api/workspace` で読み書きします |

- 2つのデータは別々で、切り替えてもコピーしません。
- アカウントでも、この Mac と同じくすべての操作ができます。変更のたびに、読み込んだときの `revision` を付けてデータ全体を保存します。別の画面で先に保存されていたとき（`409 conflict`）は、最新を読み直して同じ変更をやり直します（3回まで）。
- アカウントの単語パック（typle-r v0.91.0 から）は画面に出しませんが、読み込んだまま保存し、パックごとに単語リストを並べ替えたりしません。フォロー中の公式パックのリストは、サーバーが単語を空で返すため（typle-r v2.1.0 から）、同梱の公式パックのカタログ（`catalog.json`）から単語を戻して練習できるようにし、保存では単語を送りません。公式パックのリストは Web 版と同じく編集・削除できず（一覧に「公式」と出ます）、複製すると自分のリストとして編集できます。Macで作ったリストは、保存のときにそのリストの名前のパックに入ります。一度も保存していないアカウントは、公式パックをすべてフォローした状態で始まります（Web 版の関心の既定がすべてを選ぶのと同じ）。
- ログインは「一般」の「GitHub でログイン」で、システムのログイン画面（`ASWebAuthenticationSession`。Safari の GitHub のログインを使えます）が開きます。サーバーには `client=macos` で始め、流れは iPad と同じです（下の「ログインの流れ」）。受け取ったトークンは Mac のキーチェーンにだけ保存し、有効期限は30日です。使っているあいだは自動で延びます。
- ログアウトするとトークンを消して「この Mac」に戻ります。
- サーバーの URL は https だけです。http は `localhost`・`127.0.0.1`・`*.local` に限ります。手元の Web 版（`npm run dev`）で試すときは `http://localhost:<ポート>` を入れます。GitHub の OAuth App の callback URL がサーバー（`AUTH_URL`）のものである必要があり、開発用ログインはアプリでは使えません。
- アプリは App Sandbox の中で動き、使う権限はネットワークへの接続と、自分で選んだファイルの読み書きだけです（`Typle/Typle.entitlements`）。

## ログインの流れ

Web 版と同じ GitHub OAuth App でログインし、Cookie の代わりにトークンを使います（RFC 8252 のネイティブアプリの形）。

1. アプリが32バイトの乱数から検証値（verifier）を作り、`ASWebAuthenticationSession` で `/api/auth/signin?client=macos&code_challenge=<S256>` を開きます。
2. サーバーは GitHub でのログインの後、`typle-r://login?code=<コード>` へリダイレクトします。コードは2分で切れます。失敗・キャンセルは `typle-r://login?error=loginFailed` です。
3. アプリが `POST /api/auth/token`（`{"code","verifier"}`）を呼び、`{"token","user"}` を受け取ります。間違いはすべて `400 loginFailed` です。
4. アプリは `Authorization: Bearer <トークン>` で `/api/auth/session` と `/api/workspace` を呼びます。発行から24時間たったトークンは、`/api/auth/session` の応答の `token` で新しくなります。

サーバーの側（`client=macos` の受け付け）は typle-r にあります。

## 構成

| 場所 | 内容 |
|---|---|
| `Shared/` | typle-r の iPad 版から写した SwiftUI のコード。Mac で違うところは `#if os(macOS)` と `Support/Platform.swift`（ログインの `client`、保存データの名前など）、`Design/Theme.swift` の「The iPad and the Mac」（入力欄・メニュー・シートの見た目）。`#else` の側は iPad のときのもので、Mac のビルドには入りません |
| `TypleCore/` | 入力判定・記録・ベスト・ランキング・単語リスト・端末・CSV と、公式パックのカタログ（Swift Package） |
| `Typle/Practice/PracticeTextField.swift` | 練習欄（AppKit） |
| `Typle/MacCommands.swift` | メニューバー、CSV の保存、スクリーンショット（Debug ビルドだけ） |
| `Typle/Resources/` | アイコンと、`Shared/` の文言のうち「iPad」「タップ」を含むものの Mac 版（`Mac.strings`）。ほかの文言は `Shared/Resources` の `Localizable.strings` を使います |
| `project.yml` | XcodeGen の設定 |
| `tests/` | 文言の確認（Node.js） |

## 確認

CI のワークフローはありません。ビルドとサンプルデータ（`-TypleDemo YES`）での確認は手元で行います。

```sh
node --test tests/            # 文言（Node.js 20 以上）
TYPLE_R=../typle-r node --test tests/   # 公式パックのカタログも
cd TypleCore && swift test    # 共通の規則
```

- `tests/strings.test.cjs` が、「iPad」「タップ」を含む文言すべてに Mac 版があり、プレースホルダーがそろっているか、コードが使う文言が日本語・英語の両方にあるかを確かめます。
- `TYPLE_R` に typle-r の手元のフォルダーを指定すると、公式パックのカタログ（`catalog.json`）が typle-r の `src/plugins/packs` から作ったものと同じかも確かめます。指定しなければ、このテストは飛ばします。
- スクリーンショットは、Debug ビルドを `-TypleDemo YES -TypleSnapshot <ファイル>` で起動すると、ウインドウを PNG で保存して終わります。アプリは App Sandbox の中で動くため、保存先は `~/Library/Containers/io.github.sparklingstadt.typle/Data/tmp/` の下にします。

## 公式パックを Web 版に合わせる

`TypleCore/Sources/TypleCore/Resources/catalog.json` は、typle-r の `src/plugins/packs`（`commands/manifest.json` の順の各リスト）から作る公式パックのカタログです。Web 版の `officialPacks`・Go の `OfficialPacks` と同じパック・リスト・ID になります。直接書き換えず、typle-r で公式のリストが変わったら作り直し、`TYPLE_R` を指定したテストで同じになったことを確かめます。この端末で使う最初の単語リストも、このカタログのリストです。

```sh
node scripts/catalog.cjs ../typle-r
TYPLE_R=../typle-r node --test tests/
```

## 範囲外

App Store への公開・Apple の公証・自動更新、日本語・英語以外の言語、複数のウインドウ、保存先の間のコピー。
