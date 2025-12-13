import 'dart:convert';
import 'dart:async'; // TimeoutExceptionのために必要
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'question_detail_page.dart';
import 'tag_search_page.dart';

class QuestionBoardPage extends StatefulWidget {
  const QuestionBoardPage({super.key});

  @override
  State<QuestionBoardPage> createState() => _QuestionBoardPageState();
}

class _QuestionBoardPageState extends State<QuestionBoardPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  
  int _selectedTabIndex = 0;
  late final String serverUrl;
  bool _isLoading = false; // 投稿・削除中のローディング
  bool _isFetching = false; // データ取得中のローディング

  @override
  void initState() {
    super.initState();
    
    // ★本番想定のため、RenderのURLを使用
    serverUrl = 'https://campus-core-api.onrender.com';
    
    print('接続先サーバー: $serverUrl'); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      get_questions(); 
    });
  }

  // 🔹 ホーム画面用の全件取得
  Future<void> get_questions() async {
    if (!mounted) return;
    setState(() => _isFetching = true);

    // ★修正1: トークンを取得して、サーバーに「誰が見ているか」を伝える
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    // ヘッダーの準備（ログインしていればトークンを入れる）
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      print('データ取得開始: $serverUrl/questions');
      
      // ★修正2: headersを追加してリクエスト
      final response = await http.get(
        Uri.parse('$serverUrl/questions'),
        headers: headers, 
      ).timeout(const Duration(seconds: 60)); 

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _questions = List<Map<String, dynamic>>.from(
            data.map((e) {
              final tags = (e['tags'] as List<dynamic>?)?.cast<String>() ?? [];
              
              return {
                'id': e['id'],
                'user_id': e['user_id'],
                'text': e['text'] ?? '',
                'tags': tags,
                'user_name': e['user_name'] ?? '名無し',
                'created_at': e['created_at'],
                
                // サーバーから受け取った「いいね情報」
                'like_count': e['like_count'] ?? 0,   // 現在のいいね数
                'is_liked': e['is_liked'] ?? false,   // 自分がいいね済みか
              };
            }),
          );
        });
      } else {
         print('サーバーエラー: ${response.statusCode} ${response.body}');
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('サーバーエラー: ${response.statusCode}')),
         );
      }
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サーバーの起動待ちです。もう一度更新してください(約1分かかります)')),
      );
    } catch (e) {
      print('通信エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通信エラーが発生しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  List<String> extract_tags(String text){
    final tagPattern = RegExp(r'#(.+?)#'); 
    final match = tagPattern.allMatches(text);
    return match.map((m) => m.group(1)!).toList();
  }

  // 🔹 投稿処理
  Future<void> post_question(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('再ログインしてください')));
      setState(() => _isLoading = false);
      return;
    }
    final tags = extract_tags(text);

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'text': text, 'tags': tags}),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 201) {
        _controller.clear();
        FocusScope.of(context).unfocus();
        await get_questions(); 
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿しました！')));
        }
      } else {
        print('投稿エラー: ${response.statusCode} ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿に失敗しました')));
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラーが発生しました')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 投稿削除処理
  Future<void> delete_question(dynamic questionId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('この投稿を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return; 

    setState(() => _isLoading = true);
    
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('再ログインしてください')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/questions/$questionId'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        setState(() {
          _questions.removeWhere((q) => q['id'] == questionId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
      } else {
        print('削除エラー: ${response.statusCode} ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
      }
    } catch (e) {
      print('削除通信エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラーが発生しました')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 いいね切り替え処理 (Optimistic UI)
  Future<void> toggle_like(int index, dynamic questionId) async {
    // 1. 現在の状態を一時保存
    final bool originalLiked = _questions[index]['is_liked'];
    final int originalCount = _questions[index]['like_count'];

    // 2. 画面を【即座に】更新
    setState(() {
      final bool newLiked = !originalLiked;
      _questions[index]['is_liked'] = newLiked;
      if (newLiked) {
        _questions[index]['like_count'] = originalCount + 1;
      } else {
        _questions[index]['like_count'] = (originalCount - 1) < 0 ? 0 : (originalCount - 1);
      }
    });

    // 3. 裏でAPIリクエスト
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      // ログインしていない場合は元に戻す
      setState(() {
        _questions[index]['is_liked'] = originalLiked;
        _questions[index]['like_count'] = originalCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインしてください')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/questions/$questionId/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('いいね同期成功');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }

    } catch (e) {
      print('いいね通信エラー: $e');
      // 4. エラー発生時は元に戻す
      if (mounted) {
        setState(() {
          _questions[index]['is_liked'] = originalLiked;
          _questions[index]['like_count'] = originalCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通信エラーが発生しました')),
        );
      }
    }
  }
  
  // ------------------------------------------
  // ① ホーム画面の Widget
  // ------------------------------------------
  Widget _buildHomeView() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      children: [
        // 投稿フォーム
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '質問内容 (#タグ# でタグ付け)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : () => post_question(_controller.text),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('投稿'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 質問一覧
        Expanded(
          child: _isFetching && _questions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
              ? const Center(child: Text('まだ投稿がありません'))
              : RefreshIndicator(
                  onRefresh: get_questions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      final tags = q['tags'] as List<String>;
                      final isMyPost = currentUserId != null && q['user_id'] == currentUserId;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuestionDetailPage(questionData: q),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ヘッダー（名前・削除）
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.account_circle, size: 20, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          q['user_name'], 
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (isMyPost)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        onPressed: () => delete_question(q['id']),
                                        constraints: const BoxConstraints(), 
                                        padding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                Text(q['text'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 8),
                                
                                // タグ
                                if (tags.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    children: tags.map<Widget>((t) => Chip(
                                      label: Text('#$t'),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.blue.shade50,
                                    )).toList(),
                                  ),
                                  
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Colors.grey), 

                                // アクションバー（返信 & いいね）
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      // ❤ いいねボタン
                                      InkWell(
                                        onTap: () => toggle_like(index, q['id']),
                                        borderRadius: BorderRadius.circular(30),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              // ★ここが赤くなるポイント
                                              // is_likedがtrueならIcons.favorite(塗りつぶし) & Colors.pink
                                              Icon(
                                                q['is_liked'] ? Icons.favorite : Icons.favorite_border,
                                                size: 20,
                                                color: q['is_liked'] ? Colors.pink : Colors.grey,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${q['like_count']}',
                                                style: TextStyle(
                                                  color: q['is_liked'] ? Colors.pink : Colors.grey,
                                                  fontSize: 13,
                                                  fontWeight: q['is_liked'] ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('質問用SNS')),
      body: _selectedTabIndex == 0 
          ? _buildHomeView()
          : const TagSearchPage(),
      
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'タグ検索'),
        ],
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
      ),
    );
  }
}