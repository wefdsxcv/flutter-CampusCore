import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../learning/question_board_page.dart'; // パスは環境に合わせて調整してください

final supabase = Supabase.instance.client;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // コントローラー定義
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 修正済みのサインアップ処理
  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);

    try {
      // 1. サインアップ実行
      // data: {'name': name} を渡すことで、SQLのトリガーが拾って user_profiles に入れてくれます
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, 
      );

      // 2. ログイン状態の確認
      final session = supabase.auth.currentSession;

      if (session != null) {
        // 成功したら質問掲示板へ
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const QuestionBoardPage()),
          );
        }
      } else {
        // メール確認待ちなどの場合
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登録完了。確認メールをチェックしてください。')),
          );
          Navigator.pop(context);
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録エラー: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予期せぬエラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 【ここが足りなかった部分です！】
  // 画面のUIを構築するメソッド
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView( // キーボードが出てもエラーにならないようにスクロール可能にする
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名前（ニックネーム）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'パスワード（6文字以上）'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // ローディング中はボタンを押せないようにする
                  onPressed: _loading ? null : _signup,
                  child: _loading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      ) 
                    : const Text('登録して始める'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}