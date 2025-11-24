import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../learning/question_board_page.dart';
import 'signup_page.dart';

final supabase = Supabase.instance.client;// Supabase クライアント（ここから auth.currentSession/currentUser を参照する）


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;// ローディング状態

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();//これ何？
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;// 空チェック

    setState(() => _loading = true);
    try {
      // Supabase にメール/パスワードでサインインを試行
      await supabase.auth.signInWithPassword(email: email, password: password);
      // signInWithPassword の戻り値は SDK バージョンで異なるため、ここでは currentSession を使って成功判定している
      final session = supabase.auth.currentSession;//今のセッション情報でも取ってるの？？
      if (session != null) {
        // ログイン成功 → 質問板へ置換遷移
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QuestionBoardPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ログインに失敗しました')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ログインエラー: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            //メール入力フィールド
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'メールアドレス')),
            const SizedBox(height: 8),
            //メール入力フィールド
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'パスワード'), obscureText: true),
            const SizedBox(height: 12),
            // ログインボタン（_loading により二重送信防止）
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading ? const CircularProgressIndicator() : const Text('ログイン'),
            ),
            const SizedBox(height: 12),
            // サインアップ画面への遷移ボタン
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage()),
                );
              },
              child: const Text('アカウント未登録の方はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}