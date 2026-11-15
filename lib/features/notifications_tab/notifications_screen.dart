// ============================================================================
// حاضر — تبويب الإشعارات: سجل زمني (فحوصات/تذكيرات/قرارات اعتراض/رسائل الإدارة)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_texts.dart';
import '../../app.dart';

final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiProvider).myNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(T.tabNotifications)),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text(T.errNetwork)),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: list.isEmpty
              ? ListView(children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                        child: Text('لسه مفيش إشعارات',
                            style: TextStyle(color: Color(0xFF78716C)))),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final read = n['read_at'] != null;
                    return Card(
                      color: read ? null : const Color(0xFFECFDF5),
                      child: ListTile(
                        leading: _icon(n['notification_type'] as String? ?? ''),
                        title: Text(
                          n['title_ar'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((n['body_ar'] as String?)?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(n['body_ar'] as String,
                                    style: const TextStyle(height: 1.6)),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                DateFormat('d MMMM — h:mm a', 'ar_EG').format(
                                  DateTime.parse(n['created_at'] as String),
                                ),
                                style: const TextStyle(
                                    fontSize: 11.5, color: Color(0xFF78716C)),
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          // وسم كمقروء (سياسة notifications_mark_read_own)
                          await ref
                              .read(apiProvider)
                              .markNotificationRead(n['id'] as String);
                          ref.invalidate(notificationsProvider);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _icon(String type) => switch (type) {
        'spot_check' || 'spot_check_reminder' => const CircleAvatar(
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(Icons.radar, color: Color(0xFF0369A1))),
        'objection_decision' => const CircleAvatar(
            backgroundColor: Color(0xFFECFDF5),
            child: Icon(Icons.gavel_outlined, color: Color(0xFF15803D))),
        'manager_message' => const CircleAvatar(
            backgroundColor: Color(0xFFFEF3C7),
            child: Icon(Icons.chat_bubble_outline, color: Color(0xFFD97706))),
        _ => const CircleAvatar(child: Icon(Icons.notifications_none)),
      };
}
