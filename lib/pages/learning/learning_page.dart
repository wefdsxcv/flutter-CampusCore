// ...existing code...
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 追加: セッション確認用
import '../../widgets/module_card.dart';
import 'record_summary_page.dart';
import 'note_ocr_page.dart';
//import 'code_check_page.dart'; ここをコメントアウト
import 'question_board_page.dart';
import '../auth/login_page.dart'; // 追加: 未ログイン時の遷移先
// ...existing code...

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, Object>> modules = [
      //{'title': '録音要約（AI）', 'page': const RecordSummaryPage()},
      //{'title': 'ノート整形（OCR）', 'page': const NoteOcrPage()},
      //{'title': 'コードチェック', 'page': const CodeCheckPage()}, ここをコメントアウト
      {'title': '質問箱', 'page': const QuestionBoardPage()},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final item = modules[index];
        return ModuleCard(
          title: item['title'] as String,
          onTap: () {
            // 質問箱をタップしたときはログイン状態を確認して遷移先を変える
            if ((item['title'] as String) == '質問箱') {
              final session = Supabase.instance.client.auth.currentSession;
              if (session != null) {
                // ログイン済み → 質問板へ
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item['page'] as Widget),
                );
              } else {
                // 未ログイン → ログイン画面へ（ログイン後に質問板へ遷移する実装を LoginPage に入れてください）
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            } else {
              // 既存の遷移
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item['page'] as Widget),
              );
            }
          },
        );
      },
    );
  }
}
// ...existing code...