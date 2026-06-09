# CampusCore - 中部大学生向け質問SNS

## 概要

CampusCore は、中部大学生同士が授業や大学生活に関する情報交換を行うための質問SNSアプリです。

Yahoo!知恵袋のような Q&A 形式をベースにしつつ、大学特有の情報（授業名・教授名など）をタグとして扱うことで、中部大学に特化した情報共有を目的としています。

本プロジェクトは大学の授業「創成D」の開発課題として作成しました。

---

## 開発背景

大学生活では以下のような情報が個人間で閉じてしまうことが多くあります。

* この授業はどのような内容なのか
* この教授の試験はどのような形式なのか
* 履修に関する相談
* 学内イベントや施設に関する情報

既存の SNS では大学固有の情報を探しにくいため、

**「中部大学生だけが利用できる質問SNS」**

を目指して開発しました。

---

## 主な機能

### 投稿機能

ユーザーが質問や情報共有の投稿を行えます。

### 投稿一覧機能

作成された投稿を一覧表示します。

### 返信機能

投稿に対して返信できます。

### 返信一覧機能

投稿に紐づく返信を時系列順で表示します。

### タグ機能

投稿本文内の

```text
##Java##
##データベース##
##○○教授##
```

のような記述をタグとして認識します。

### タグ検索機能

タグを指定して関連する投稿を検索できます。

### ユーザー認証

Supabase Authentication を利用した

* 新規登録
* ログイン
* JWT認証

に対応しています。

### いいね機能

投稿へのいいね・いいね解除が可能です。

* 二重いいね防止
* いいね数キャッシュ
* 自分がいいね済みか判定

を実装しています。

---

## 今後実装予定

* DM機能
* WebSocket を利用したリアルタイム通信
* 通知機能
* 画像アップロード
* 投稿削除
* 通知集約
* プッシュ通知（FCM）

---

# 技術スタック

## フロントエンド

| 技術      | バージョン     |
| ------- | --------- |
| Flutter | 開発時最新版    |
| Dart    | Flutter同梱 |

### 採用理由

* Android アプリと Web を同一コードベースで開発可能
* 学習コストと開発速度のバランスが良い

---

## バックエンド

| 技術      | バージョン  |
| ------- | ------ |
| Node.js | 開発時最新版 |
| Express | 開発時最新版 |

### 採用理由

* JavaScript による高速開発
* Flutter との相性が良い
* API 開発が容易

---

## データベース

| 技術                   | 用途    |
| -------------------- | ----- |
| Supabase(PostgreSQL) | メインDB |
| Supabase Auth        | 認証    |

### 採用理由

* PostgreSQL を利用できる
* Authentication が利用可能
* 個人開発でも扱いやすい

---

## 非同期処理

| 技術             | 用途       |
| -------------- | -------- |
| Redis          | キュー管理    |
| BullMQ         | ジョブキュー   |
| Outbox Pattern | 通知イベント管理 |

### 採用理由

通知処理を API から分離し、

* レスポンス速度向上
* 冪等性の確保
* 再試行対応

を行うため。

---

## メール通知

| 技術     | 用途    |
| ------ | ----- |
| Resend | メール送信 |

### 採用理由

SMTP 認証不要で API 経由で送信可能なため。

---

# システム構成

```text
Flutter
   ↓
Node.js API
   ↓
Supabase(PostgreSQL)

       ↓
    Outbox
       ↓
     Redis
       ↓
    BullMQ
       ↓
    Worker
       ↓
   Notification
```

---

# アーキテクチャ

クリーンアーキテクチャを参考に実装しています。（DDD無し。）

```text
src/

├─ routes/
├─ controllers/
├─ usecases/
├─ repositories/
├─ infra/
└─ db/
```

### routes

APIルーティング定義

### controllers

HTTPリクエスト処理

### usecases

業務ロジック

### repositories

DBアクセス

### infra

外部サービス連携

### db

Supabase接続設定

---

# データベース設計

主なテーブル

```text
user_profiles
questions
tags
question_tags
replies
likes
outbox
notifications
```

## ERイメージ

```text
User
 ├─ Questions
 │    └─ Replies
 │
 └─ Likes

Questions
 └─ Tags
      ↑
 QuestionTags
```

---

# 認証フロー

## ユーザー登録

```text
ユーザー登録
    ↓
Supabase Auth
    ↓
auth.users
    ↓
Trigger
    ↓
user_profiles作成
```

## ログイン

```text
Login
 ↓
JWT取得
 ↓
Local Storage保存
 ↓
認証付きAPI利用
```

---

# いいね機能

以下を実装しています。

* Like
* Unlike
* 二重登録防止
* Like Count キャッシュ
* 通知イベント発行

処理は PostgreSQL RPC によるトランザクションで実行しています。

---

# 通知システム

通知は Outbox Pattern を利用しています。（常時起動worker サーバーを予算的な問題で実装できず、ローカルでworker を立ち上げて体験という形に）

```text
Like
 ↓
Outbox Insert
 ↓
Worker監視
 ↓
Redis Queue
 ↓
 Worker
 ↓
通知送信
```

### 対応済み

* 非同期通知
* Retry
* Debounce

---

# 開発環境

## Redis

```bash
docker compose up -d
```

## API

```bash
npm install
npm run dev
```

## Worker

```bash
node worker.js
```

---

# Web版公開

Flutter Web を GitHub Pages にデプロイしています。

```bash
flutter build web
flutter pub global run peanut
git push origin gh-pages
```

---

# 学習・検証内容

本プロジェクトでは以下の技術の学習を兼ねています。

* クリーンアーキテクチャ
* Repository Pattern
* PostgreSQL
* Supabase
* Redis
* BullMQ
* Outbox Pattern
* メール通知
* 非同期処理
* Flutter
* JWT認証

---

# ライセンス

個人学習目的プロジェクト
