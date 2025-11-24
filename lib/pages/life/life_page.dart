import 'package:flutter/material.dart';
import '../../widgets/module_card.dart';
import 'phone_restriction_page.dart';

class LifePage extends StatelessWidget {
  const LifePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, Object>> modules = [
      {'title': '深夜スマホ制限', 'page': PhoneRestrictionPage()},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final item = modules[index];
        return ModuleCard(
          title: item['title'] as String,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item['page'] as Widget),
          ),
        );
      },
    );
  }
}