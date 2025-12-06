学校の創成Dという授業で作成したアプリです。andoroidモバイルアプリを考えて開発しました。
webようにbluidしてgit hub page にpushしたのでぜひ見てみてください。
私は質問snsという　yahoo知恵袋の下位互換みたいな機能を担当しました。
私は質問投稿や情報交換ができるsnsを作りました。対象ユーザーは中部大学生で、中部大学生同士が情報交換できるsnsを目指して設計しました。　主な機能は投稿一覧、投稿、返信一覧、返信、タグ検索　機能です。　　教授名、授業名をタグに含めて投稿することにより、中部大学特化の情報交換snsとして機能することができます。
他のメンバーが開発した機能に関してはapikeyを直書き？？してるとかなんとか、どこに書いてあるかもわからなとのことなので、載せません。
　　
zennをメモとして作業履歴（どうしてこのコードを書いたorコピペしてきたか等を書く）つもりだったが、readmeでいいや。
本アプリの機能要件を整理。投稿一覧機能、投稿機能（##で囲むことでタグとして認識）、返信一覧機能、返信機能、タグ検索機能。
～拡張～
削除機能、いいね機能、画像アップロード、通知機能（キャッシュ）を実現していく。


　　　　　　　　　　　　　　　　　　　　　　
開発の流れ
クリーンアーキテクチャ　の設計思想でやる。少し違うためzennの記事参照して。
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
    id SERIAL PRIMARY KEY,  **serialはautoincrementのこと＊＊
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
-- 3. 中間テーブル (Question - Tags)　（多対多）一つの質問に複数タグ。1つのタグに複数の質問
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

-- ---------------------------------------------------
-- 1. テーブル作成
-- ---------------------------------------------------

-- イイネテーブル　（多対多）中間テーブル   行があるってことはいいねしてるってことね？
CREATE TABLE likes (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,　　　誰が、どの投稿にいいねしたか管理する。uqnie制約付き。
    question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,　　　　　　1 人のユーザーは、複数の投稿にいいねする。
    　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　1 つの投稿は、複数のユーザーからいいねされる。なのでuserテーブル、質問テーブルにリレーション関係を記述しても多対多なので、うまく管理できない。そのため、中間テーブルを作成。
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, question_id) -- 同じ投稿に2回イイネできない制約
);

-- 通知テーブル（将来用）
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    receiver_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE, -- 通知を受け取る人
    sender_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,   -- 通知を送った人
    question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,           -- 対象の質問（どの投稿に対する通知か分かるようにするため）　ON DELETE CASCADE → 投稿が消えたら通知も消える
    type VARCHAR(20) NOT NULL CHECK (type IN ('like', 'reply')),                   -- 種類　CHECK このカラムに入れていい値を制限する
    is_read BOOLEAN DEFAULT FALSE,                                                 -- 既読　BOOLEAN　true false
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 質問テーブルに「いいね数」カラムを追加
ALTER TABLE questions 
ADD COLUMN like_count INT DEFAULT 0;　　　//likes テーブルを COUNT すれば「いいね数」は分かる。しかし、毎回 COUNT すると重い。質問テーブルにいいね数を保存しておく = キャッシュするという意味らしい。✔ イイネするたびに +1 / -1 更新する（UPDATE questions SET like_count = like_count + 1 WHERE id=?;）

-- ---------------------------------------------------
-- 2. イイネ切り替え関数（Atomic処理）
-- ---------------------------------------------------

① イイネ済みか確認する

likes テーブルに
「user_id = 自分 & question_id = 投稿」
の組み合わせがあるか確認。

▼ ② イイネ済 → イイネ取り消し

likes から削除

通知も削除

like_count - 1

{ liked: false } を返す

▼ ③ イイネ未 → イイネ追加

likes に追加

投稿者を調べる

投稿者 ≠ 自分なら通知を追加

like_count + 1

{ liked: true } を返す

▼ ④ どんな結果だったか JSON で返す

CREATE OR REPLACE FUNCTION toggle_like(_user_id uuid, _question_id bigint) 
RETURNS jsonb AS $$     -- この関数は “jsonb を返す関数” とDBに宣言している
DECLARE                 -- ここから「変数宣言パート」
  v_exists boolean;             -- イイネ済みかどうか(true/false)
  v_question_owner uuid;        -- 投稿の持ち主の user_id を一時的に入れる変数
  v_result jsonb;               -- 最後に返すJSONを作るための変数
BEGIN                    -- ここから「処理（トランザクション）」が始まる
                         -- PostgreSQLの関数はBEGIN〜ENDが“1つのまとまり”として実行される

  -- ★ STEP1: 既にイイネしているかチェック（likes に行があるかチェック）
  SELECT EXISTS(
      SELECT 1 FROM likes 
      WHERE user_id=_user_id AND question_id=_question_id
  ) INTO v_exists;               -- 結果(true/false)を v_exists に保存

  -- ★ STEP2: イイネ済みなら取り消し処理
  IF v_exists THEN               -- もし既にいいねしていたら…
    
    -- likes から削除（イイネ取り消し）
    DELETE FROM likes 
      WHERE user_id=_user_id AND question_id=_question_id;
    
    -- 通知テーブルからも削除（同じイイネ通知を消す）
    DELETE FROM notifications 
      WHERE sender_id=_user_id 
      AND question_id=_question_id 
      AND type='like';

    -- 質問テーブルの like_count を 1 減らす ※0以下にはならないようにGREATESTを使用
    UPDATE questions 
      SET like_count = GREATEST(0, like_count - 1) 
      WHERE id=_question_id;
    
    -- 結果をJSONに詰める
    v_result := jsonb_build_object('liked', false);

  ELSE                          -- ★ STEP3: イイネ未なら追加処理

    ここでlikesテーブルに行（データ）追加  
    -- likes にイイネを追加
    INSERT INTO likes(user_id, question_id) 
    VALUES(_user_id, _question_id);

    -- 投稿者の user_id を取り出す（通知に使う）
    SELECT user_id 
      FROM questions 
      WHERE id=_question_id 
      INTO v_question_owner;

    -- 投稿者が自分以外なら通知を作成する
    IF v_question_owner IS NOT NULL 
       AND v_question_owner <> _user_id THEN
      INSERT INTO notifications(receiver_id, sender_id, question_id, type)
      VALUES(v_question_owner, _user_id, _question_id, 'like');
    END IF;
    
    -- like_count を 1 増やす（NULL の可能性があるので COALESCE）
    UPDATE questions 
      SET like_count = COALESCE(like_count,0) + 1 
      WHERE id=_question_id;
    
    -- 結果を JSON に詰める
    v_result := jsonb_build_object('liked', true);
  END IF;

  -- ★ STEP4: JSON を返す
  RETURN v_result;

END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

（getリクエスト修正、投稿に対するいいね数（questionテーブルのlike_count カラムから取得（このカラムを作ったのは、likeテーブルからcount でやると激重だから。（countは該当する行の数を数える。アクセスが増える→getリクエスト増える→もし毎回question_idに合致するlikesテーブルの行を全捜索すると？？））と誰が、どの投稿にいいねしているかを保持しているlikesテーブルから自分（現在ログインしているユーザーid）がどの投稿にいいねしているかをselectする（フロントでいいね済みを表示するため）。あとは今まで通り、質問テキスト、question_tagsのtagsテーブルのidを元にtagsテーブルのnameカラム、questionテーブルにあるリレーション関係のユーザーidを元に user_profilesのname カラムを取得。）

// ---------------------------------------------------
// 1. 全件取得 (Get All Questions)
// ---------------------------------------------------
export async function getAllQuestions(req, res) {
  try {
    // A. まず質問データ一覧を取得
    // selectの中に 'like_count' が含まれるので、特別記述しなくても '*' で取得されます
    const { data: questions, error } = await supabase
      .from("questions")
      .select(`
        *,
        tags:question_tags(
          tag:tags(name)
        ),
        profile:user_profiles(name)
      `)
      .order("created_at", { ascending: false });

    if (error) throw error;

    // -------------------------------------------------
    // B. 「自分がイイネした質問ID」のリストを作る
    // -------------------------------------------------
    let myLikedQuestionIds = [];

    // トークンがある場合（ログインしている場合）のみチェック
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      // ユーザー特定
      const { data: { user } } = await supabase.auth.getUser(token);
      
      if (user) {
        // likesテーブルから、自分のuser_idに紐づくquestion_idだけ取ってくる
        const { data: myLikes } = await supabase
          .from("likes")
          .select("question_id")
          .eq("user_id", user.id);
        
        // [{question_id: 1}, {question_id: 5}] 
        //   ↓ mapで変換
        // [1, 5] というシンプルな配列にする
        if (myLikes) {
          myLikedQuestionIds = myLikes.map(like => like.question_id);
        }
      }
    }

    // -------------------------------------------------
    // C. データ整形 (Flutterに送る形を作る)
    // -------------------------------------------------
    const formattedData = questions.map(post => ({
      ...post,
      tags: post.tags ? post.tags.map(t => t.tag.name) : [],
      user_name: post.profile ? post.profile.name : '名無し',
      
      // ★ここが追加ポイント
      // DBのカラム(like_count)をそのまま使う。NULLなら0にする。
      like_count: post.like_count ?? 0, 
      
      // さっき作ったIDリストに含まれていれば true、なければ false
      is_liked: myLikedQuestionIds.includes(post.id)
    }));

    res.status(200).json(formattedData);

  } catch (err) {
    console.error("全件取得失敗:", err);
    res.status(500).json({ error: "質問一覧の取得に失敗しました" });
  }
}

// POST /questions/question_id/like  (イイネ切り替え)　
router.post("/:id/like", toggleLike);  　　　追加。

// 7. イイネの切り替え (Toggle Like)　toggle_like(_user_id uuid, _question_id bigint) db関数を作ったので、
// URL: POST /questions/:id/like
// ---------------------------------------------------
export async function toggleLike(req, res) {
  try {
    // URLの :id は文字列で来るので、DBに合わせて数値(Int)に変換します
    const questionId = parseInt(req.params.id);
    
    // ① トークンチェック（おなじみの流れ）
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) return res.status(401).json({ error: "ログインしてください" });

    // ② ユーザー特定
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) return res.status(401).json({ error: "無効なトークン" });

    // ③ Supabaseの関数 (RPC) を呼び出す
    // .rpc('関数名', { 引数名: 値 }) という書き方です
    const { data, error } = await supabase.rpc('toggle_like', {
      _user_id: user.id,　　//誰が
      _question_id: questionId　　//なんの投稿
    });

    if (error) throw error;

    // DB関数から返ってきた { "liked": true } などをそのままフロントへ返します
    res.status(200).json(data);

  } catch (err) {
    console.error("イイネ処理失敗:", err);
    res.status(500).json({ error: "処理に失敗しました" });
  }
}



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
　
# 1. Webサイトを作り直す（ここが重要）
flutter pub global run peanut --extra-args "--base-href=/flutter-CampusCore/"

# 2. GitHubに送る
git push origin gh-pages

