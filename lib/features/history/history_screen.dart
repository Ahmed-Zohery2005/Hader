// ============================================================================
// حاضر — سجلي (الجزء 3.3): تسجيلات آخر 7 أيام بشفافية كاملة
// «بترس بالظبط اللي بيشوفه مديرك» + مشاهدة فيديوي برابط 5 دقائق
// + دورة الاعتراض الرسمية (7 أيام نافذة — التثبيت تلقائي على السيرفر)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_texts.dart';
import '../../app.dart';

final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiProvider).myCaptures();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(T.tabHistory)),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text(T.errNetwork)),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(historyProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  T.transparencyNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('لسه مفيش تسجيلات — أول تسجيل هيظهر هنا',
                        style: TextStyle(color: Color(0xFF78716C))),
                  ),
                ),
              ...list.map((r) => _CaptureTile(row: r)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final type = row['capture_type'] as String? ?? '';
    final status = row['final_status'] as String? ?? 'pending';
    final reason = row['review_reason_ar'] as String?;
    final at = DateTime.parse(row['captured_at_server'] as String);
    final offline = row['client_monotonic_delta_ms'] != null;
    final late = row['late_upload_advisory'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _typeIcon(type),
        title: Text(
          '${_typeAr(type)} — ${DateFormat('EEEE d MMMM', 'ar_EG').format(at)}'
          ' ${DateFormat('h:mm a', 'ar_EG').format(at)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(_statusAr(status), _statusColor(status)),
              _chip(_gradeAr(row['location_grade'] as String?), const Color(0xFF0369A1)),
              if (offline) _chip(T.offlineTag, const Color(0xFF78716C)),
              if (late) _chip(T.lateUploadTag, const Color(0xFFD97706)),
              if (reason != null && reason.isNotEmpty)
                _chip(reason, const Color(0xFFB45309)),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CaptureDetailScreen(row: row),
        )),
      ),
    );
  }

  Widget _typeIcon(String t) {
    switch (t) {
      case 'check_in':
        return const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.login, color: Color(0xFF15803D)));
      case 'check_out':
        return const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.logout, color: Color(0xFF4B5563)));
      case 'spot_check':
        return const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.radar, color: Color(0xFF0369A1)));
      default:
        return const CircleAvatar(child: Icon(Icons.videocam));
    }
  }

  String _typeAr(String t) => switch (t) {
        'check_in' => 'حضور',
        'check_out' => 'انصراف',
        'spot_check' => 'فحص مفاجئ',
        'kiosk_capture' => 'تسجيل كشك',
        _ => t,
      };

  String _statusAr(String s) => switch (s) {
        'pending' => T.statusPending,
        'auto_accepted' => T.statusAutoAccepted,
        'needs_review' => T.statusNeedsReview,
        'manager_accepted' => T.statusManagerAccepted,
        'manager_rejected' => T.statusManagerRejected,
        'asked_employee' => T.statusAskedEmployee,
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'auto_accepted' || 'manager_accepted' => const Color(0xFF15803D),
        'needs_review' => const Color(0xFFD97706),
        'manager_rejected' => const Color(0xFFDC2626),
        _ => const Color(0xFF78716C),
      };

  String _gradeAr(String? g) => switch (g) {
        'confirmed' => T.gradeConfirmed,
        'probable' => T.gradeProbable,
        'needs_review' => T.gradeNeedsReview,
        'gps_only' => T.gradeGpsOnly,
        _ => '—',
      };

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

// ============================================================================
// تفاصيل التسجيل: الفيديو (رابط 5 دقائق) + دورة الاعتراض
// ============================================================================

class CaptureDetailScreen extends ConsumerStatefulWidget {
  const CaptureDetailScreen({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  ConsumerState<CaptureDetailScreen> createState() => _CaptureDetailState();
}

class _CaptureDetailState extends ConsumerState<CaptureDetailScreen> {
  VideoPlayerController? _player;
  bool _loadingVideo = false;
  String? _videoError;

  Future<void> _loadVideo() async {
    setState(() {
      _loadingVideo = true;
      _videoError = null;
    });
    final res = await ref.read(apiProvider).requestOwnVideoUrl(
          widget.row['id'] as String,
        );
    if (!res.ok || res.data == null) {
      setState(() {
        _loadingVideo = false;
        _videoError = res.error ?? T.errGeneric;
      });
      return;
    }
    try {
      _player?.dispose();
      _player = VideoPlayerController.networkUrl(
        Uri.parse(res.data!['view_url'] as String),
      );
      await _player!.initialize();
      setState(() => _loadingVideo = false);
      _player!.play();
    } catch (_) {
      setState(() {
        _loadingVideo = false;
        _videoError = T.videoExpired;
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// هل الاعتراض متاح؟ (نافذة 7 أيام من تاريخ التسجيل — تُتحقق السيرفر مجددًا)
  bool get _objectionAllowed {
    final at = DateTime.parse(widget.row['captured_at_server'] as String);
    return DateTime.now().difference(at).inDays < 7;
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.row['r2_object_key'] != null &&
        widget.row['media_deleted_at'] == null;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل التسجيل')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!hasVideo)
            const _NoteBox(
              'الفيديو اتمسح تلقائيًا بعد 7 أيام — البيانات النصية متاحة',
              Color(0xFFF1F5F9),
            )
          else if (_player != null && _player!.value.isInitialized)
            AspectRatio(
              aspectRatio: _player!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_player!),
                  VideoProgressIndicator(_player!, allowScrubbing: true),
                ],
              ),
            )
          else
            _NoteBox(
              _videoError ?? T.watchVideo,
              _videoError != null ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
              onTap: _loadingVideo ? null : _loadVideo,
              loading: _loadingVideo,
            ),
          const SizedBox(height: 18),

          // زر الاعتراض الرسمي
          if (_objectionAllowed)
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel_outlined),
              onPressed: () => _openObjectionFlow(context),
              child: const Text(T.objectionButton),
            )
          else
            const _NoteBox(T.objectionWindowOver, Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  /// دورة الاعتراض (7 خطوات — الجزء 3.3): سبب من قائمة + سطر توضيحي
  Future<void> _openObjectionFlow(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(T.objectionTitle,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            ),
            _reasonTile(ctx, T.objectionReason1),
            _reasonTile(ctx, T.objectionReason2),
            _reasonTile(ctx, T.objectionReason3),
            _reasonTile(ctx, T.objectionReason4),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('سطر توضيحي (اختياري)'),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(hintText: T.objectionNoteHint),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(T.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(T.objectionSend),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    final res = await ref.read(apiProvider).submitObjection(
          captureId: widget.row['id'] as String,
          presetReason: reason,
          note: note,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.ok ? T.objectionSent : (res.error ?? T.errGeneric))),
    );
  }

  Widget _reasonTile(BuildContext ctx, String label) => ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14.5)),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.pop(ctx, label),
      );
}

class _NoteBox extends StatelessWidget {
  const _NoteBox(this.text, this.color, {this.onTap, this.loading = false});

  final String text;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (onTap != null)
              const Icon(Icons.play_circle_outline),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}
