import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionDetailPage extends StatefulWidget {
  // 前の画面から受け取るデータ（親の投稿データ）
  final Map<String, dynamic> questionData;

  const QuestionDetailPage({super.key, required this.questionData});

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = false;
  late final String serverUrl;

  @override
  void initState() {
    super.initState();
    serverUrl = dotenv.env['PROD_SERVER_URL'] ?? 'http://localhost:3000';
    // 画面が開いたらすぐに返信一覧を取りに行く
    getReplies();
  }

  // 1. 返信一覧を取得 (GET)
  Future<void> getReplies() async {
    final questionId = widget.questionData['id'];
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/questions/$questionId/replies'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _replies = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('返信取得エラー: $e');
    }
  }

  // 2. 返信を投稿 (POST)
  Future<void> postReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('再ログインしてください')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/questions/replies'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'question_id': widget.questionData['id'], // 親のIDを紐付け
        }),
      );

      if (response.statusCode == 201) {
        _replyController.clear();
        // キーボードを閉じる
        FocusScope.of(context).unfocus();
        // リストを更新して自分の返信を表示
        await getReplies();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送信失敗')));
      }
    } catch (e) {
      print('送信エラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 親の投稿データを見やすく取り出し
    final q = widget.questionData;
    final tags = q['tags'] as List<String>;

    return Scaffold(
      appBar: AppBar(title: const Text('返信')),
      body: Column(
        children: [
          // ------------------------------------------
          // ① リスト部分 (親投稿 + 返信一覧)
          // Expanded で残りのスペースを全部使う
          // ------------------------------------------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // === 親の投稿カード ===
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50, // 少し色を変えて目立たせる
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_circle, size: 30, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(q['user_name'] ?? '名無し', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(q['text'], style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 12),
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: tags.map((t) => Chip(label: Text('#$t'))).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 30, thickness: 2),
                const Text('返信一覧', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),

                // === 返信リスト ===
                if (_replies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: Text('まだ返信はありません')),
                  ),

                ..._replies.map((reply) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          children: [
                            const Icon(Icons.account_circle, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(reply['user_name'] ?? '名無し', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(reply['text'], style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // ------------------------------------------
          // ② 下部入力エリア (固定)
          // ------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: const InputDecoration(
                        hintText: '返信を投稿する...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : postReply,
                    style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(16)),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}