# GABUGABU

**書いた言葉を、ひとくちで保存。**

![GABUGABU — ショートカットで文章をローカル保存](assets/social.png)

AIへのプロンプトも、ページで見つけた一節も、書きかけの考えも。選んで **Command + Option + S** を押すだけで、自分のMacにMarkdownで残せる小さなアプリです。気になる言葉をどんどんためて、あとでAIに読ませるメモに。

**[Mac版をダウンロード →](https://github.com/hrk877/gabugabu/releases/latest)**

macOS 13以降 / Apple Silicon・Intel両対応 / 無料・MIT License

1.4.0ではMacアプリの文章取得を改善し、直接取得できない画面を自動コピーで補助します。

## どう使う？

1. [Releases](https://github.com/hrk877/gabugabu/releases/latest) の **GABUGABU-1.4.0-mac.zip** をダウンロードして展開。
2. **GABUGABU.app** を「アプリケーション」へ移して開く。
3. 初回だけ「アクセシビリティ設定を開く」から **GABUGABU** を許可する。
4. 普段のアプリに戻り、文章を選択して **⌘⌥S** を押す。

入力中の文章は、何も選択していなければ入力欄全体を保存します。画面下部、Dockの少し上に小さな黄色の「Saved」が出たら完了。アプリを開いてノートを作ったり、タイトルを付けたりする必要はありません。

![Savedの保存完了通知](assets/saved-toast@2x.png)

保存通知は95×23pt、メインカラーは#F9C70D。細い文字とロゴの上下端を揃え、約1.6秒で消えます。エラー時は日本語で理由を表示します。

直接取得できない画面では、選択部分へ自動で **⌘C** を送り、コピーできた文章を保存します。Notion・Googleドキュメント・Canvaなど、通常のコピーができる文章への対応を広げる補助方式です。Canvaでは文字の編集状態で文章自体を選択してください。図形や画像の選択は対象外です。

![操作イメージ・架空の文章を使ったデモ](assets/demo.gif)

デモは架空の文章を使った操作イメージです。口と記録の一覧は「選んだ言葉がたまる」様子の表現で、実際のアプリはメニューバーから使います。文章以外の画像・音声・動画は保存しません。

## どこに残る？

**GABUGABU Archive** に日付別で追記します。

```text
~/GABUGABU/Archive/
├── 2026-10-26.md
├── 2026-10-27.md
└── …
```

原文に加え、日時・アプリ名・記録ID・選択／全文の区別を記録。画面タイトル・ページURL・書類パスも、取得できる場合は自動で付けます。取れない項目は空欄です。同じ文章でも、押した回数だけ保存します。日付はMacのタイムゾーン、各記録の時刻はUTCです。

AIにローカルファイルを読む権限があれば「GABUGABU Archiveから、先週のアイデアを探して」と頼めます。通常のChatGPTが自動でこのフォルダーへ接続されるわけではありません。クラウドAIに読ませた内容は、そのAIに送られます。

## 対応範囲

- macOSのアクセシビリティで取得できる選択文と、編集可能な入力欄を優先します。取れない場合は自動コピーで補助します。
- アプリ経由でフォーカスが取れない場合は、macOS全体のフォーカス情報を同じプロセスか照合します。アプリ切り替え時には取得の準備だけを行い、Electron製アプリでは必要に応じてアクセシビリティ情報を有効にします。初回の準備待ちは最大1.5秒、コピーの応答待ちは最大2秒です。取得元が不明なままコピーはしません。
- Webページや書類の選択文にも対応しますが、アプリによって取得できない画面があります。
- 選択文が取れないとき、読み取り専用ページを丸ごと保存することはありません。
- 自動コピーは文章を選択して使います。全選択は自動で行いません。コピー禁止の画面・画像内だけの文字・取得元を確認できない画面には対応しません。すべてのアプリでの動作保証はありません。
- URLやタイトルの取得可否もアプリ次第です。URLを得るために別のタブや履歴を探すことはありません。
- パスワード欄と主なパスワード管理アプリは対象外。通常の文章中の秘密情報を自動で見分ける機能はありません。
- ショートカットが他アプリと重なる場合は、そちらの設定を変更してください。

### 実アプリで確認した範囲

Notion・LINEでは、アプリ切り替え後の最初の⌘⌥Sで保存できることをユーザーテストで確認しました。Canvaでは文字編集状態の選択文、Obsidian・Codex・ボイスメモでも選択文の保存を確認しています。これは確認した画面・操作についての結果で、全アプリ・全画面での動作保証ではありません。GoogleドキュメントとCanvaのオブジェクト選択だけの状態は、別途検証が必要です。

## ローカル保存について

GABUGABU自体の外部通信・アカウント・AI API・課金はありません。キー入力の常時記録はせず、文章はショートカットを押したときだけ取得します。アプリ切り替え時の準備では入力位置の識別だけを行い、選択文や入力欄の内容は読み取りません。

不具合の切り分け用に、取得の段階・プロセス番号・エラー番号・文字数だけをmacOSのシステムログへ記録します。本文・画面タイトル・URL・クリップボードの内容はログへ出しません。

自動コピーの補助方式では、現在のクリップボードを全形式で退避してから⌘Cを送り、コピー結果を保存前に復元します。退避できない場合や8 MiBを超える場合はコピーしません。古いコピー内容をそのまま保存することもありません。画面移動や取得中の変更を検出した場合は中止し、新しいコピーを上書きしないようにします。

**コピー中は別のコピーや画面移動をせずお待ちください。** コピー結果は一時的にクリップボード履歴アプリへ見えるため、復元しても履歴に残る場合があります。OSのコピー情報だけでは書き込み元を完全には特定できず、別アプリが同時にクリップボードを書き換える場合の誤取得・復元を完全には防げません。遅れてコピーが完了した場合や、途中で画面を切り替えた場合は、クリップボードに選択文が残ることがあります。

記録は平文Markdownです。新規フォルダーは所有者だけアクセス可能（700）、ファイルは所有者だけ読み書き可能（600）。同じユーザー権限を持つアプリやバックアップから読める場合があり、自分で同期対象にすればクラウドにも同期されます。

## 初回の警告・権限設定

この配布版はアドホック署名で、Apple Developer ID署名・公証は未実施です。ダウンロード後、macOSに起動を止められる場合があります。入手元を確認したうえで「システム設定 → プライバシーとセキュリティ → このまま開く」から許可してください。OSのバージョンによって表示は異なります。

アクセシビリティ一覧に見つからない場合は「＋」からGABUGABU.appを追加します。更新後、オンなのに権限エラーが出るときは、一覧から一度「−」で削除し、現在のアプリを追加し直してください。

起動後はメニューバーの「文章＋」アイコンから保存先・使い方・終了を選べます。ログイン時にも起動したい場合は、macOSのログイン項目に追加してください。

## 旧版「ことばログ」から

旧アプリを終了してからGABUGABUを起動してください。旧保存先 `~/PromptArchive/` は、新しい `~/GABUGABU/Archive/` へ自動で移します。両方の保存先がすでに存在する場合、旧記録はArchive内の `Imported-PromptArchive-…/` に保管し、同じ日付のファイルを上書きしません。旧形式のMarkdownもそのまま読めます。

## 自分でビルド

Xcode Command Line ToolsがあるMacで実行。外部ライブラリー不要です。

```bash
/bin/bash test.sh
/bin/bash build.sh
```

通知の実画像と通常・Retina両方の上下端検証は、以下で生成・実行できます。

```bash
/usr/bin/xcrun swiftc -swift-version 5 Sources/Toast.swift Tools/PreviewToast/main.swift -o build/preview-toast
build/preview-toast
```

`dist/GABUGABU.app` と `dist/GABUGABU-1.4.0-mac.zip` が生成されます。テストは保存・同時追記・選択ポリシー・メタデータ・記録移行・パス検証・取得期限・コピー補助を確認します。実ペーストボードのテストは専用の名前付き領域だけを使用し、通常のクリップボードには触れません。サンドボックスではペーストボードサービスへのアクセスが許可されず、このテストが失敗する場合があります。

AX取得期限のテストは外部APIを代役に置き換えて実際のCapture処理を実行するもので、実アプリの互換性を保証するものではありません。実際のアプリ間取得は権限設定後に別途確認してください。JSONの`capture_method`で直接取得（`accessibility`）とコピー補助（`copy`）を区別できます。

不具合は [Issues](https://github.com/hrk877/gabugabu/issues) へ。実際の保存内容や個人情報をそのまま貼らず、再現する画面と手順を教えてください。

## English

GABUGABU saves selected text—or the current accessible editable input—to local daily Markdown with **Command + Option + S**. When Accessibility cannot provide text, it sends one targeted Cmd+C and attempts to restore a full clipboard snapshot. Clipboard-history apps may retain the temporary copy. Avoid other copy operations during capture; concurrent clipboard writers cannot be fully attributed. No network, account, AI API, or continuous key logging. macOS 13+, Apple Silicon and Intel. Accessibility permission is required. This build is ad-hoc signed and not notarized. Copy-protected content, images, and some app surfaces are unsupported; universal compatibility is not guaranteed.

MIT License.
