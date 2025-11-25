import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 

  const supabaseUrl = 'https://yqjktyinndgqoqnnvqev.supabase.co'; // あなたのSupabase URL
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlxamt0eWlubmRncW9xbm52cWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1OTA1OTcsImV4cCI6MjA3ODE2NjU5N30.fJaV6-FS3I2j1rRV70RATeWBnO5yC-JH91tuE4MtwSE'; // あなたのSupabase Anon Key

  // 修正箇所: URLそのものではなく、.envで定義した「キー名」を指定します
  await Supabase.initialize(
    url:supabaseUrl   ,    
    anonKey: supabaseAnonKey
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