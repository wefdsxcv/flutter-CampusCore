import 'dart:convert';
import 'dart:async'; // TimeoutExceptionのために必要
import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart'; // 切り替えロジックを削除したので不要
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
  bool _isLoading = false; // 投稿中のローディング
  bool _isFetching = false; // データ取得中のローディング

  @override
  void initState() {
    super.initState();
    
    // ★修正: 本番想定のため、常にRenderのURLを使用するように固定
    // .envの PROD_SERVER_URL を読み込みます。なければダミー(エラーになります)
    serverUrl = 'https://campus-core-api.onrender.com';
    
    print('接続先サーバー: $serverUrl'); // デバッグ用にログ出力

    WidgetsBinding.instance.addPostFrameCallback((_) {
      get_questions(); 
    });
  }

  // 🔹 ホーム画面用の全件取得
  Future<void> get_questions() async {
    if (!mounted) return;
    setState(() => _isFetching = true);

    try {
      // ★Renderのスリープ対策: タイムアウトを60秒に設定
      print('データ取得開始: $serverUrl/questions');
      
      final response = await http.get(Uri.parse('$serverUrl/questions'))
          .timeout(const Duration(seconds: 60)); 

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _questions = List<Map<String, dynamic>>.from(
            data.map((e) {
              final tags = (e['tags'] as List<dynamic>?)?.cast<String>() ?? [];
              return { //quesion id 等すべての情報を配列（リストに保持）
                'id': e['id'],
                'text': e['text'] ?? '', 
                'tags': tags,
                'user_name': e['user_name'] ?? '名無し',
                'created_at': e['created_at'],
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
      // ★Renderのスリープ対策: タイムアウトを60秒に設定
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

  // ------------------------------------------
  // ① ホーム画面の Widget
  // ------------------------------------------
  Widget _buildHomeView() {
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
          // データ取得中はローディング、空ならメッセージ、あればリスト
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
                                const SizedBox(height: 8),
                                Text(q['text'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 8),
                                if (tags.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    children: tags.map<Widget>((t) => Chip(
                                      label: Text('#$t'),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.blue.shade50,
                                    )).toList(),
                                  ),
                                const SizedBox(height: 4),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text('返信', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                )
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