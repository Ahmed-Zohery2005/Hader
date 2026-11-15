// ============================================================================
// حاضر — شاشة الأسئلة الشائعة (موسوعة/أكورديون)
// ============================================================================
import 'package:flutter/material.dart';
import 'faq_data.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأسئلة الشائعة')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: kFaq.length,
        itemBuilder: (_, i) => Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              kFaq[i].q,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              Text(kFaq[i].a, style: const TextStyle(height: 1.8, color: Color(0xFF4B5563))),
            ],
          ),
        ),
      ),
    );
  }
}
