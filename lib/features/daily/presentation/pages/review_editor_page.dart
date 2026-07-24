import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/moment_repository.dart';
import '../providers/review_providers.dart';

/// 复盘编辑页（P4-2）。
///
/// 结构化引导：心情 + 高光 / 待改进 / 明日计划。打开即聚合当日全景（财务
/// 日常/摊销/真实成本 · 摄入/消耗/净热量 · 待办完成率）展示为「当前全景」，
/// 保存时把该快照**冻结**进 `summarySnapshotJson`
/// （[ReviewNotifier.saveReview]）。若当日已有复盘，则另展示其冻结快照（历史不随
/// 后续数据变化）。页底部关联展示当日 [LifeMoment]（瞬间）。
///
/// 只依赖 [ReviewRepository] 接口与 [DailyReviewSnapshot] 纯模型，无 `db.`/
/// `Companion`/裸查询（§1.1）。读取均走 `.watch()` 流派生 provider，写后自动刷新。
class ReviewEditorPage extends ConsumerStatefulWidget {
  const ReviewEditorPage({super.key});

  @override
  ConsumerState<ReviewEditorPage> createState() => _ReviewEditorPageState();
}

class _ReviewEditorPageState extends ConsumerState<ReviewEditorPage> {
  static const _moods = ['😊', '😌', '😐', '😔', '🤩', '🥲', '😤', '🥰'];

  final _highlightController = TextEditingController();
  final _improveController = TextEditingController();
  final _tomorrowController = TextEditingController();

  String _mood = _moods.first;
  bool _loaded = false; // 是否已把已存复盘预填进控制器（防覆盖用户编辑）
  bool _saving = false;

  @override
  void dispose() {
    _highlightController.dispose();
    _improveController.dispose();
    _tomorrowController.dispose();
    super.dispose();
  }

  void _onReviewArrived(DailyReviewLogData? row) {
    if (_loaded || row == null) return;
    _loaded = true;
    _highlightController.text = row.highlightText ?? '';
    _improveController.text = row.improveText ?? '';
    _tomorrowController.text = row.tomorrowPlanText ?? '';
    // 直接赋值（不 setState）：本回调由 build() 内 whenData 早于 mood 选择器
    // 调用，同帧内 _buildMoodPicker 即读到新值；_loaded 守卫保证只预填一次，
    // 不覆盖用户随后的 ChoiceChip 选择（那些走 onSelected → setState）。
    if (row.moodTag.trim().isNotEmpty) {
      _mood = row.moodTag.trim();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(reviewProvider.notifier).saveReview(
            moodTag: _mood,
            highlightText: _highlightController.text.trim().isEmpty
                ? null
                : _highlightController.text.trim(),
            improveText: _improveController.text.trim().isEmpty
                ? null
                : _improveController.text.trim(),
            tomorrowPlanText: _tomorrowController.text.trim().isEmpty
                ? null
                : _tomorrowController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日复盘已保存')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(reviewProvider);
    // 首次拿到已存复盘时预填（一次性）。
    reviewAsync.whenData(_onReviewArrived);

    final snapshot = ref.watch(todayReviewSnapshotProvider);
    final moments = ref.watch(todayMomentsProvider);
    // 已存复盘的冻结快照（历史）。
    final frozen = reviewAsync.maybeWhen(
      data: (row) => row == null ? null : DailyReviewSnapshot.decode(row.summarySnapshotJson),
      orElse: () => null,
    );
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: ModuleColors.daily,
        foregroundColor: Colors.white,
        title: Text('今日复盘 · ${now.month}-${now.day}'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildMoodPicker(),
            const SizedBox(height: 16),
            _buildSectionField(
              icon: '🌟',
              label: '今日高光',
              hint: '一件让你开心或有成就感的小事…',
              controller: _highlightController,
            ),
            const SizedBox(height: 12),
            _buildSectionField(
              icon: '🔍',
              label: '待改进',
              hint: '哪里可以做得更好？',
              controller: _improveController,
            ),
            const SizedBox(height: 12),
            _buildSectionField(
              icon: '🎯',
              label: '明日计划',
              hint: '明天最想推进的一两件事…',
              controller: _tomorrowController,
            ),
            const SizedBox(height: 20),
            _buildSnapshotCard(
              title: '今日全景',
              subtitle: '保存时冻结为快照，复盘后不再随后续数据变化',
              snapshot: snapshot,
            ),
            if (frozen != null) ...[
              const SizedBox(height: 12),
              _buildSnapshotCard(
                title: '复盘时冻结的全景',
                subtitle: '历史快照：即使今天的支出/运动继续变化，这里不变',
                snapshot: frozen,
                accent: const Color(0xFF9E9E9E),
              ),
            ],
            const SizedBox(height: 20),
            _buildMomentsSection(moments),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── 心情选择 ──

  Widget _buildMoodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('心情', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final mood in _moods)
              ChoiceChip(
                label: Text(mood, style: const TextStyle(fontSize: 20)),
                selected: _mood == mood,
                onSelected: (_) => setState(() => _mood = mood),
                selectedColor: ModuleColors.daily.withAlpha(60),
              ),
          ],
        ),
      ],
    );
  }

  // ── 结构化文本框 ──

  Widget _buildSectionField({
    required String icon,
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── 全景快照卡 ──

  Widget _buildSnapshotCard({
    required String title,
    required String subtitle,
    required DailyReviewSnapshot snapshot,
    Color? accent,
  }) {
    final base = accent ?? ModuleColors.daily;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base.withAlpha(15), base.withAlpha(40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
          const SizedBox(height: 12),
          Row(
            children: [
              _snapshotTile('日常', '¥${snapshot.spotExpense.toStringAsFixed(0)}'),
              _snapshotTile('摊销', '¥${snapshot.amortizedExpense.toStringAsFixed(0)}'),
              _snapshotTile('真实成本', '¥${snapshot.trueExpense.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _snapshotTile('摄入', '${snapshot.intakeCalories.toStringAsFixed(0)} kcal'),
              _snapshotTile('消耗', '${snapshot.burnedCalories.toStringAsFixed(0)} kcal'),
              _snapshotTile(
                '净热量',
                '${snapshot.netCalories.toStringAsFixed(0)} kcal',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _snapshotTile(
                '待办',
                '${snapshot.todoCompleted}/${snapshot.todoTotal}',
              ),
              _snapshotTile(
                '完成率',
                '${(snapshot.todoCompletionRate * 100).round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 当日瞬间 ──

  Widget _buildMomentsSection(List<MomentWithPhotos> moments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日瞬间 · ${moments.length}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (moments.isEmpty)
          const Text(
            '今天还没有记录瞬间。回到「日常」可随手拍一张。',
            style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
          )
        else
          Column(
            children: [
              for (final m in moments) _buildMomentRow(m),
            ],
          ),
      ],
    );
  }

  Widget _buildMomentRow(MomentWithPhotos m) {
    final content = (m.moment.content == null || m.moment.content!.trim().isEmpty)
        ? '（纯照片瞬间）'
        : m.moment.content!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.moment.moodTag != null && m.moment.moodTag!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(m.moment.moodTag!, style: const TextStyle(fontSize: 18)),
                  ),
                Text(content, style: const TextStyle(fontSize: 13)),
                if (m.photoPaths.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '📷 ${m.photoPaths.length} 张',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    ),
                  ),
              ],
            ),
          ),
          if (m.photoPaths.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(m.photoPaths.first),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFFBDBDBD)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
