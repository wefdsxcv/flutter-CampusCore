import 'package:flutter/material.dart';
import 'learning/learning_page.dart';
//import 'life/life_page.dart';
import 'settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    LearningPage(),
    //LifePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CampusCore'), centerTitle: true),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,//タップすると発火
        items: const [//タブ？？遷移しているだけ、よー分からんが、BottomNavigationBar の onTap → setState → bodyのWidget切り替え　　uicomponetを切り替えてるだけぽい。　
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '学習'),
          //BottomNavigationBarItem(icon: Icon(Icons.self_improvement), label: '生活'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}