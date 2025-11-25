import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'question_detail_page.dart'; // 詳細画面への遷移用

class TagSearchPage extends StatefulWidget {
  const TagSearchPage({super.key});

  @override
  State<TagSearchPage> createState() => _TagSearchPageState();
}

class _TagSearchPageState extends State<TagSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false; // 「検索したかどうか」のフラグ
  late final String serverUrl;

  @override
  void initState() {
    super.initState();
    serverUrl =  'http://localhost:3000';
  }

  // 🔹 タグ検索実行
  Future<void> searchByTag() async {
    final tag = _searchController.text.trim();
    if (tag.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResults = []; // 結果を一度リセット
    });

    try {
      // Node.js の getQuestionsByTag API を叩く
      final response = await http.get(
        Uri.parse('$serverUrl/questions/tag/$tag'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(
            data.map((e) {
              final tags = (e['tags'] as List<dynamic>?)?.cast<String>() ?? [];
              return {
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
        print('検索失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('検索エラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ----------------------------------
        // ① 上部：検索フォーム
        // ----------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'タグ名を入力 (例: Flutter)',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => searchByTag(), // エンターキーでも検索
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : searchByTag,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
              ),
            ],
          ),
        ),
        
        // ----------------------------------
        // ② 下部：検索結果リスト
        // ----------------------------------
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _hasSearched ? '該当する投稿は見つかりませんでした' : 'タグを入力して検索してください',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final q = _searchResults[index];
                        final tags = q['tags'] as List<String>;

                        // ホーム画面と同じカードデザイン
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () {
                              // タップで詳細画面へ (ホームと同じ挙動)
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}