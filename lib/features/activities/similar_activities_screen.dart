import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/training_analysis_service.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';

class SimilarActivitiesScreen extends StatefulWidget {
  const SimilarActivitiesScreen({super.key, required this.activity});
  final ActivityRecord activity;
  @override
  State<SimilarActivitiesScreen> createState() => _SimilarActivitiesScreenState();
}
class _SimilarActivitiesScreenState extends State<SimilarActivitiesScreen> {
  List<ScoredSimilar> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = await TrainingAnalysisService.instance.getSimilarWithScores(widget.activity);
    if (!mounted) return;
    setState(() { _items = list; _loading = false; });
  }
  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    if (d.inHours > 0) return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }
  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
  Color _similarityColor(double v) {
    if (v >= 90) return Colors.green;
    if (v >= 75) return Colors.orange;
    if (v >= 50) return Colors.blue;
    return Colors.grey;
  }
  Widget _buildImage(ActivityRecord a) {
    try {
      if (a.photoPath != null && a.photoPath!.isNotEmpty) {
        final f = File(a.photoPath!);
        if (f.existsSync()) return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(f, width: 56, height: 56, fit: BoxFit.cover));
      }
    } catch (_) {}
    if (a.thumbnailUrl != null && a.thumbnailUrl!.isNotEmpty) return SecureImage(imageUrl: a.thumbnailUrl, width: 56, height: 56, borderRadius: 12, fit: BoxFit.cover);
    return Container(width: 56, height: 56, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.directions_run, color: Theme.of(context).colorScheme.primary));
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text("Похожие тренировки" + (_loading ? "" : " (${_items.length})")), centerTitle: true),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: cs.outline), const SizedBox(height: 12), Text("Нет похожих тренировок", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)), const SizedBox(height: 6), Text("Выполните ещё тренировки такого же типа, чтобы увидеть сравнение.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]))]))) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, i) {
        final s = _items[i];
        final a = s.activity;
        final col = _similarityColor(s.similarity);
        return InkWell(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a))); }, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceVariant.withOpacity(0.25), borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant.withOpacity(0.4))), child: Row(children: [_buildImage(a), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(a.title ?? a.kind.labelRu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.5))), child: Text("${s.similarity.toStringAsFixed(0)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col)))]), const SizedBox(height: 4), Text(_formatDate(a.startedAt), style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 6), Row(children: [_miniStat(Icons.straighten, "${s.targetDistanceKm.toStringAsFixed(1)} км"), const SizedBox(width: 10), _miniStat(Icons.timer_outlined, _formatDuration(s.targetDurationSec)), const SizedBox(width: 10), _miniStat(Icons.speed, "${s.targetSpeed.toStringAsFixed(1)} км/ч")]), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: s.similarity / 100, minHeight: 4, backgroundColor: col.withOpacity(0.15), color: col)), const SizedBox(height: 4), Wrap(spacing: 8, children: [if (s.distDeltaPct.abs() > 0.5) Text("Дист. ${s.distDeltaPct > 0 ? "+" : ""}${s.distDeltaPct.toStringAsFixed(1)}% ", style: TextStyle(fontSize: 10, color: s.distDeltaPct.abs() < 10 ? Colors.green : Colors.orange)), if (s.durationDeltaPct.abs() > 0.5) Text("Время ${s.durationDeltaPct > 0 ? "+" : ""}${s.durationDeltaPct.toStringAsFixed(1)}% ", style: TextStyle(fontSize: 10, color: s.durationDeltaPct.abs() < 10 ? Colors.green : Colors.orange)), if (s.speedDeltaPct.abs() > 0.5) Text("Скор. ${s.speedDeltaPct > 0 ? "+" : ""}${s.speedDeltaPct.toStringAsFixed(1)}% ", style: TextStyle(fontSize: 10, color: s.speedDeltaPct.abs() < 10 ? Colors.green : Colors.orange))])])), const SizedBox(width: 6), Icon(Icons.chevron_right, color: cs.outline)])));
      }),
    );
  }
  Widget _miniStat(IconData icon, String text) { return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: Colors.grey[600]), const SizedBox(width: 3), Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey))]); }
}
