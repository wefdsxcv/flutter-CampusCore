import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // 修正箇所: URLそのものではなく、.envで定義した「キー名」を指定します
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,      // .env の SUPABASE_URL を読み込む
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!, // .env の SUPABASE_ANON_KEY を読み込む
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusCore',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansJP',
      ),
      // スマホアプリ想定でも、開発中は一旦 HomePage を表示してUI確認するのはOKです
      home: const HomePage(),
    );
  }
}