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

-- イイネテーブル　（多対多）中間テーブル   行があるってことはいいねしてるってこと
CREATE TABLE likes (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,　　　誰が、どの投稿にいいねしたか管理する。uqnie制約付き。
    question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,　　　　　　1 人のユーザーは、複数の投稿にいいねする。
    　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　1 つの投稿は、複数のユーザーからいいねされる。なのでuserテーブル、質問テーブルにリレーション関係を記述しても多対多なので、うまく管理できない。そのため、中間テーブルを作成。
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, question_id) -- 同じ投稿に2回イイネできない制約
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

2025/12/10　職務分離usecase repository infra にクライアント生成を
2025/12/11  通知処理（outbox パターン（redisあり））　を実装していく。

-- 1. Outboxテーブルの作成（通知したかを管理するためだけのテーブル）
CREATE TABLE IF NOT EXISTS outbox (　　　　　　　　　　　　　　if not exists はまだ同じテーブル名がなかったら、作成。
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),           
    aggregate_id TEXT,             -- 関連するID（今回は返信ID）
    type VARCHAR(50) NOT NULL,     -- イベントの種類（'reply_created'など）
    payload JSONB NOT NULL,        -- 通知に必要なデータ（誰から誰へ、など）
    status VARCHAR(20) DEFAULT 'pending', -- 'pending' -> 'sent'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- 高速化のためのインデックス
CREATE INDEX IF NOT EXISTS idx_outbox_status_created ON outbox(status, created_at);

~outboxテーブル説明～
UUID = 重複しないランダム ID

gen_random_uuid() は Postgres の UUID 自動生成関数

→ Outbox の1件ずつの「イベント」を識別するための ID

＊～indexの理由～＊ outbox Worker が「未処理（pending）の行」だけを高速に SELECT する必要があるから
🔥 Outbox パターンでは「この SELECT がめちゃくちゃ頻発する」

outbox Worker はずっとこんなクエリを投げ続ける：outbox worker　→ outboxテーブルからpendingの行を取って、redisにjobを追加する別起動隊サーバー

SELECT * FROM outbox
WHERE status = 'pending'   -- ① pending のやつだけ探す
ORDER BY created_at ASC    -- ② 古い順に並べる
LIMIT 1;                   -- ③ 最初の1個だけ取る

②  outbox Worker が処理後にやること
UPDATE outbox
SET status = 'sent'
WHERE id = ?;

インデックスがない場合（Full Table Scan）
本に例えると「目次がない状態」です。

DBは outbox テーブルの 全ページ（全行） を上から下まで全部見ます。

pending と書かれた行をすべてピックアップします。

ピックアップした行を、メモリ上で created_at の順番に 並べ替え（ソート） します。

やっと1番上のデータを返します。 👉 データが100万件あったら、毎回100万件チェックして並べ替えが発生します。激重です。

＊負荷が増えたらやること＊
段階① index 追加（安全）
CREATE INDEX idx_outbox_type_status
ON outbox(type, status);

段階② JSON をカラムに切り出す
ALTER TABLE outbox
ADD COLUMN sender_id uuid,
ADD COLUMN receiver_id uuid;

段階③ 部分 index
CREATE INDEX idx_outbox_like_pending
ON outbox(sender_id)
WHERE type='create_like_notification'
  AND status='pending';


＊usecases/reply/postreplyusecase.js　＊
import { replyRepository } from "../../repositories/replyRepository.js";
// 質問の投稿者を確認するために必要
import { questionRepository } from "../../repositories/questionRepository.js"; 

export async function postReplyUsecase(text, questionId, userId) {
  // 1. 質問情報を取得（通知先＝質問の投稿者 を特定するため）
  // ※ questionRepository.findById が必要です
  const { data: questionData, error: qError } = await questionRepository.findById(questionId);
  
  if (qError || !questionData) {
    throw new Error("質問が見つかりません");
  }

  // 2. Outbox用ペイロードの準備
  let outboxPayload = null;

  // 「自分の投稿への返信」ではない場合のみ通知データを作る
  if (questionData.user_id !== userId) {
    outboxPayload = {
      type: "reply",
      senderId: userId,               // 返信した人 (あなた)
      receiverId: questionData.user_id, // 通知を受け取る人 (質問者)
      questionId: questionId
    };
  }

  // 3. トランザクション実行 (RPC経由)
  // 返信の保存と、Outboxへの保存が同時に行われます
  const { data: replyData, error } = await replyRepository.createWithOutbox(
    text, 
    questionId, 
    userId, 
    outboxPayload
  );

  if (error) throw error;

  return replyData;
}
＊　findById　＊
// question_idを元に検索。　questionテーブルにはid pk user_id リレーションuserテーブルのidを参照。text varchar2 createdを取得。
  async findById(id) {
    return await supabase
    .from("questions")
    .select("*")
    .eq("id", id)
    .single();　　　single()オブジェクト１件で返す。今回は元投稿は確実に一つのため。普通は配列（配列の中にオブジェクト）でかえって来る。
  }
＊replyRepository.js　reateWithOutbox＊
// ★ [追加] トランザクション付き作成 (返信 + Outbox)
  // DBの create_reply_with_outbox 関数を呼び出します
  async createWithOutbox(text, questionId, userId, outboxPayload) {
    const { data, error } = await supabase.rpc('create_reply_with_outbox', {       rpc関数を呼ぶ。
      _text: text,　　　＊supabaseのrpc関数の引数が_text　この引数にこの値を渡しますよと明記。引数＊呼び出し元から渡された値を受け取って保持するための変数名を宣言する所。
      _question_id: questionId,
      _user_id: userId,
      _outbox_payload: outboxPayload // 通知不要なら null を渡す
    });

    if (error) throw error;
    return { data, error: null }; // insert().select() と形を合わせるため
  }
＊★重要: トランザクション用関数 (RPC)　返信テーブルへのinsertとoutboxテーブルへのinsertを同じトランザクション内で実現＊
-- 返信のINSERTと、OutboxへのINSERTを「ひとまとめ」に行う関数です
CREATE OR REPLACE FUNCTION create_reply_with_outbox(
    _text TEXT,
    _question_id BIGINT,
    _user_id UUID,
    _outbox_payload JSONB DEFAULT NULL -- 通知が不要な場合はNULLを許容
) 
RETURNS JSONB AS $$
DECLARE
    new_reply_id BIGINT;
    result_data JSONB;
BEGIN
    -- A. 返信テーブルへ INSERT
    INSERT INTO replies (text, question_id, user_id)
    VALUES (_text, _question_id, _user_id)
    RETURNING id INTO new_reply_id;

    -- 返信データを取得して結果用変数に入れる（フロントに返すため）
    SELECT jsonb_build_object(
        'id', r.id,
        'text', r.text,
        'question_id', r.question_id,
        'user_id', r.user_id,
        'created_at', r.created_at
    ) INTO result_data
    FROM replies r WHERE r.id = new_reply_id;

    -- B. Outboxテーブルへ INSERT (ペイロードがある場合のみ)
    IF _outbox_payload IS NOT NULL THEN
        INSERT INTO outbox (aggregate_id, type, payload)
        VALUES (
            new_reply_id::TEXT,        -- 関連ID
            'create_reply_notification', -- イベントタイプ
            _outbox_payload            -- UseCaseから渡されたデータ
        );
    END IF;

    -- 返信データを返す
    RETURN result_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

これで返信テーブルinsert、outboxテーブルinsert　トランザクション

2025/12/14 いいね処理の関数を見てみると、notificationテーブル（通知用）にinsert 、いいねのトグル（post,delete）をトランザクション内でやっており、現在の通知処理をout boxテーブルにinsert worker 1がoutboxテーブル監視、redisにjob投入、2がredisのjob監視、通知を作成（notificationテーブルに）という流れと完全に違うため　修正必要。

通知は
誰が（sender）
誰に（receiver）
何をしたか（type, target）　　　が最低限必要。


～いいね連打による通知対策～
通知のデバウンス（Debounce）＊
いいねされても即座に通知を作らず、少し（例えば数分）待つ。
その間に「いいね解除」されたら、通知は送らない。
これで「間違って押してすぐ消した」場合や「連打」による通知爆撃を防ぎます。
通知の集約（Aggregation）＊
「Aさんがいいねしました」
「Bさんがいいねしました」
と個別に送るのではなく、
「Aさんと他10人があなたの投稿にいいねしました」 とまとめて1通の通知にする。
再通知の制限＊
一度いいねして通知を送った後、解除してまたすぐにいいねしても、2回目の通知は送らない（あるいは、一定時間は無視する）。

今回は、 ★デバウンス処理★ 
    -- Workerがまだ処理していない(pending)通知予約があれば削除する　で実装。

outbox worker はoutboxテーブルにリクエストを送り続けるのでindexを貼る。
-- 高速化のためのインデックス
CREATE INDEX IF NOT EXISTS idx_outbox_status_created ON outbox(status, created_at);

～toggle_like～
CREATE OR REPLACE FUNCTION toggle_like(_user_id uuid, _question_id bigint) 
RETURNS jsonb AS $$
DECLARE
  v_exists boolean;
  v_question_owner uuid;
  v_result jsonb;
BEGIN

  -- 1. 既にいいね済みかチェック
  SELECT EXISTS(
      SELECT 1 FROM likes 
      WHERE user_id=_user_id AND question_id=_question_id
  ) INTO v_exists;

  IF v_exists THEN 
    -- ▼▼▼ 【いいね解除 (Unlike) の処理】 ▼▼▼
    
    -- A. likes から削除
    DELETE FROM likes 
      WHERE user_id=_user_id AND question_id=_question_id;
    
    -- B. カウントを減らす
    UPDATE questions 
      SET like_count = GREATEST(0, like_count - 1) 
      WHERE id=_question_id;

    -- C. ★デバウンス処理★ 
    -- Workerがまだ処理していない(pending)通知予約があれば削除する
    -- これにより「間違って押してすぐ消した」場合、通知は送信されない
    DELETE FROM outbox 
      WHERE aggregate_id = _question_id::TEXT
      AND type = 'create_like_notification'
      AND (payload->>'senderId')::UUID = _user_id
      AND status = 'pending';

    v_result := jsonb_build_object('liked', false);

  ELSE 
    -- ▼▼▼ 【いいね (Like) の処理】 ▼▼▼

    -- A. likes に追加
    INSERT INTO likes(user_id, question_id) 
    VALUES(_user_id, _question_id);

    -- B. 投稿者を特定
    SELECT user_id FROM questions WHERE id=_question_id INTO v_question_owner;

    -- C. カウントを増やす
    UPDATE questions 
      SET like_count = COALESCE(like_count,0) + 1 
      WHERE id=_question_id;

    -- D. ★Outboxに追加★（自分以外の投稿なら）
    -- 通知テーブルへのINSERTはここで行わず、Workerに任せる
    IF v_question_owner IS NOT NULL AND v_question_owner <> _user_id THEN
      INSERT INTO outbox (aggregate_id, type, payload)
      VALUES (
        _question_id::TEXT,
        'create_like_notification', -- Workerが識別するジョブ名
        jsonb_build_object(
            'type', 'like',
            'senderId', _user_id,
            'receiverId', v_question_owner,
            'questionId', _question_id
        )
      );　　json（notificationテーブルに入れるための情報を保持。最低限の誰が誰になんの質問でtype,questionId）
    END IF;
    
    v_result := jsonb_build_object('liked', true);
  END IF;

  RETURN v_result;

END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

2025/12/15 outbox worker とredisのdockerfile 等　

docker.compose.yaml
services:
  redis:
    image: redis:7
    container_name: local-redis
    ports:
      - "6379:6379"

bullmq install
npm install bullmq ioredis

2025/12/16  
同時並行のゴミ箱満タン検知プロジェクトでも通知処理を行う。
あっちではpostgresql生でやる予定。　SDKとDB生での違いはzennの記事に。

フェーズ2：ローカル開発環境の構築（Docker）
クラウドに上げる前に、自分のPCで「API」と「Worker」が連携する環境を作ります。

やること:

docker-compose.yml を作成し、redis を立ち上げる。

package.json に bullmq と ioredis をインストールする。

.env ファイルに、ローカルRedisとSupabaseのURLを設定する。

確認方法:

docker-compose up でRedisが正常に起動すること。

フェーズ3：アプリの「役割切り替え」とRelayの実装
Node.js側で、ドキュメントにある「Relay（監視役）」を作ります。

やること:

main.js で process.env.APP_ROLE による分岐を書く。

Relayロジックの実装（5秒ごとにOutboxテーブルをSELECTし、BullMQのQueueに add し、statusを sent に更新する）。

確認方法:

APP_ROLE=worker でアプリを起動。

DBに手動で pending データを入れ、5秒後にDBの status が sent に変わり、コンソールに「Job added to Redis」と出るか見る。

フェーズ4：Consumer（通知実行役）の実装
Redisに溜まったジョブを処理する部分を作ります。

やること:

Worker (BullMQ) クラスの実装。

とりあえずは console.log で「〇〇さんに通知を飛ばします」と表示させるだけでOK。

確認方法:

RelayがRedisにジョブを入れた瞬間、Consumerがそれを検知してログを出力するか確認。これでバックエンドのパイプラインが完成します。

フェーズ5：外部連携（FCM & クラウドデプロイ）
最後に、本物の通知と本物のサーバーへ繋ぎます。

やること:

FCM設定: Firebase Admin SDKを導入し、Consumerの中で実際に通知を飛ばすコードを書く。

Upstash設定: ローカルRedisをUpstashのURLに切り替える。

デプロイ: APIをRenderへ、Worker（Relay+Consumer）をKoyebへデプロイ。

確認方法:

Flutterアプリから「いいね」を押し、数秒後にAndroidの実機に通知が届いたら完全勝利です。


2026/04/06
WorkerもRedisもローカル
通知発火させたい　APIの中で　redis 追加のAPIを発火
worker がredis（キュー）にあるタスクを　順（FIFO）で処理。

redis　docker で起動。 
  -p 6379:6379 \
  --name redis-test \

ioredis npmライブラリ
node.js からredis コンテナに接続するための　ライブラリ（ドライバ）
npm install ioredis
（bullmqの下位互換。キュー処理を 自分で実装しないといけない  ）

BullMQ は Node.js で非同期処理を安全に、確実に、並列で実行するための仕組み。BullMQ は Worker と Queue をつなぐライブラリ
Queue（キュー）
Worker（ワーカー）
Scheduler（スケジューラー）
Events（イベント）

npm install bullmq

queeue.js をプロジェクトのルートフォルダに作る。　
Queue 名（"notification"）は Worker と一致させる。

usecase （いいね発火させたいAPIの途中の中で） notificationQueue.add("sendLikeNotification",  キュー名.add("job名" ) 追加

worker はプロジェクトフォルダ内において、別サーバーとして実行させたい。⇒サーバーが別かどうかは「フォルダ」ではなく「プロセス」で決まる。別の node プロセスとして起動すれば、それは 別サーバーとして動く。

Queue も Worker も Redis に接続する必要がある。
それぞれ独立したプロセスだから、接続設定も別々に必要。

Queue（Usecase）
→ Redis に「仕事を追加」するために接続が必要

Worker
→ Redis から「仕事を取り出す」ために接続が必要

今回は完全ローカルでの学習のための実装のため、addJobTest.jsでキューを追加して、テスト。（本来は通知処理を発火させたいAPIの中でキュー追加するが）

テスト確認。
2026/04/06終了。　 次回はnode何とかのライブラリを入れてgmail通知を実装。

2026/04/09　
gmail送りたいので、今回はこれ
npm install nodemailer

Gmail API（公式）

メール配信サービス
SendGrid
Mailgun
Amazon SES

などを使う。

Nodemailer → Gmail の SMTP サーバーに接続
→ メールを送信
→ Gmail が相手に届ける


helpから　アプリパスワード発行あった。

アプリパスワードをユーザーに発行してもらって、入力、、、。サービスとして無理。どうすんの？　⇒　SendGrid / Mailgun / Amazon SES　　ＲＥＳＥＮＤ





再送処理
BullMQ は retry（再試行）機能
キュー.addの時に、追加。
await notificationQueue.add(
  "sendLikeNotification",
  { userId, questionId },
  {
    attempts: 3,       // 最大3回再試行
    backoff: 5000,     // 失敗したら5秒後に再試行
  }
);


2026/04/13
nodemailer だとアプリパスワード打って、、、他のユーザ―へのメール送信不可能　⇒　resenｄ使う。

RESEND,SENDGRIDはAPI叩くだけで通知を送れる外部サービス。

今後の開発方針はZENNに記載。


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

