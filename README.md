学校の創成Dという授業で作成したアプリです。andoroidモバイルアプリを考えて開発しました。
私は質問snsという　yahoo知恵袋の下位互換みたいな機能を担当しました。
私は質問投稿や情報交換ができるsnsを作りました。対象ユーザーは中部大学生で、中部大学生同士が情報交換できるsnsを目指して設計しました。　主な機能は投稿一覧、投稿、返信一覧、返信、タグ検索　機能です。　　教授名、授業名をタグに含めて投稿することにより、中部大学特化の情報交換snsとして機能することができます。
他のメンバーが開発した機能に関してはapikeyを直書き？？してるとかなんとか、どこに書いてあるかもわからなとのことなので、載せません。
　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　
開発の流れ
node.jsのフォルダ構成について。
route/ route定義をまとめる　contololler に書いた関数をまとめてimport。route定義をまとめてexport
contoroller/ 実際の処理ロジックを書く。
db/ db設定用の処理（今回はsupabaseに接続するためのurlやkeyを記述し、supabaseクライアントを生成）

プロジェクト直下　server.js  サーバー起動用ファイル。route/ のroute定義をimport
プロジェクト直下  .env db/に直接api keyやら書くとよくないので、.envに書いておく。.envから参照（import dotenv from "dotenv";そのためにこれが必要）

supabaseのテーブル設計
-- ---------------------------
-- 1. 質問テーブル (Questions)
-- ---------------------------
CREATE TABLE questions (
    id SERIAL PRIMARY KEY,
    -- 【修正点】auth.users ではなく user_profiles を参照する
    user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    text VARCHAR(2000) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------
-- 2. タグテーブル (Tags)
-- ---------------------------
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- ---------------------------
-- 3. 中間テーブル (Question - Tags)
-- ---------------------------
CREATE TABLE question_tags (
    question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (question_id, tag_id)
);

-- ---------------------------
-- 4. 返信テーブル (Replies)
-- ---------------------------
CREATE TABLE replies (
    id SERIAL PRIMARY KEY,
    question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    -- ツリー構造（返信への返信）対応
    parent_reply_id INT REFERENCES replies(id) ON DELETE CASCADE,
    -- 【修正点】ここも user_profiles を参照
    user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    text VARCHAR(2000) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------
-- 5. DMテーブル (DMs - 未実装)
-- ---------------------------
CREATE TABLE dms (
    id SERIAL PRIMARY KEY,
    -- 送信者・受信者ともに user_profiles を参照
    sender_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    text VARCHAR(2000) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE -- 既読機能用に追加しておくと便利
);
-- 1. 最小限のプロフィールテーブル
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE, -- SupabaseのAuth IDと紐付け
    name VARCHAR(100) NOT NULL -- 表示名
);

-- 2. ユーザー登録時に自動で user_profiles に行を作る関数
-- Flutter側から送られてくる "name" データをここで受け取ります
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, name)　　　　user_id とnameを入れてる。
  VALUES (
    new.id, 
    -- メタデータに名前があればそれを使う、なければ '名無し' にする
    COALESCE(new.raw_user_meta_data->>'name', 'No Name')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. トリガーのセット（auth.users に追加されたら上記関数を実行）
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


andoroid emulateを使う時に、<uses-permission android:name="android.permission.INTERNET" />　　インタネットを許可するため
andoroid studio .xml

<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- ★★★ ここにこの1行を必ず追加してください！ ★★★ -->
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:allowBackup="true"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:fullBackupContent="@xml/backup_rules"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.MyApplication">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:label="@string/app_name"
            android:theme="@style/Theme.MyApplication">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>

認証流れ
learning ページからquestion_boardページに遷移する時、ログイン状態（ローカルストレージにjwtトークンがあるか）→question_boardページへ　ない→　loginページへ。loginページでemailとpasswordを入力するとjwtトークンが渡される。(login ページに新規登録画面に遷移するボタンがあり、新規登録画面でusername,email,passwordを入力し、送信すると、supabaseは.authテーブルにuser_id,email,passwordをハッシュ化して保存。トリガー関数が動き、自身のuser テーブルにuser_id,usernameを保存。jwtトークンをフロントに）

question_boardページ
投稿機能
初回レンダリング時に、getリクエスト（jwtトークンを送っているため、user_idは分かる）→questionテーブル全件と、queston_idを元に中間テーブルからtag_idを見に行き、そこからtagテーブルのテキストを取得。userテーブルからusername を取得。フロント側でquestion_id配列index管理。カード形式はfutter 側のui部品にある。

postリクエスト（header jwt body text、フロント側で正規表現で抜き出したtag（配列になっている）→jwtトークンからuser_idが分かるので、questionテーブルにtextとuser_idを保存。今作られたquestion.idを取得。タグを検索し、あったらそのtag.idを取得。なかったらinsertしてそのtag.idを取得。
取得したquestion.idとtag.idを中間テーブルに保存。

返信機能　
タップ時に発火。getリクエスト（header jwt パスパラメータ(url)にquestion_idを付与）→question_idを元にrepliesテーブルのquestion_idのものだけ、createdカラムをasc（古い順に）取得。userテーブルからuser nameを取得。

postリクエスト(header jwt  body question_id)→repliesテーブルに返信text、question_id, user_idを追加。



git hub 
git branch -M main
git remote add origin https://github.com/ユーザー名/リポジトリ名     ここでorigin  
git push -u origin main                                            origin 


設計図の世界 (main ブランチ)

ここには Dartのプログラムコード を置きます。

あなたがさっき git push -u origin main でやったのがこれです。これはBuildの前に行うのが正解です。

完成品の世界 (gh-pages ブランチ)

ここには BuildしてできたWebサイト（HTML/JS） を置きます。

これはこれからやる作業です。

git hub page に公開する方法
flutter pub global activate peanut　ツールを入れる。

エラー
Aさん（WSL / Ubuntu側）： 以前設定したので、gitの名刺を持っています。

Bさん（Windows / PowerShell側）： まだ設定していないので、名刺を持っていません。

あなたは普段「Aさん（WSL）」として作業していますが、今回実行したコマンドの一部が、裏側で「Bさん（Windows）」としてGitを使おうとしました。 すると、Windows側のGitが**「えっ、Bさんって誰ですか？ 名刺（設定）がないから記録させません！」**と止めてしまったのです。
PS C:\Users\aigur\CampusCore\campuscore_new> git config --global user.name "ユーザー名"
PS C:\Users\aigur\CampusCore\campuscore_new> git config --global user.email "メアド"
でwindows　os　にgitのアカウントを教えている。
　
git hub でwebでbuildしてくれている？？
flutter pub global run peanut --extra-args "--base-href=/flutter-CampusCore/"


