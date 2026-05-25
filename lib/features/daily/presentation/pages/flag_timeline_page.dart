import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/daily_providers.dart';
import '../widgets/add_flag_drawer.dart';

class FlagTimelinePage extends ConsumerWidget {
  const FlagTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(flagListProvider);
    final active = flags.where((f) => !f.isCompleted).length;
    final done = flags.where((f) => f.isCompleted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Flag 目标'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildSummaryBar(active, done),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: flags.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _FlagCard(flag: flags[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddFlagDrawer(),
        ),
        child: const Icon(Icons.flag),
      ),
    );
  }

  Widget _buildSummaryBar(int active, int done) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildMiniStat('进行中', active, ModuleColors.daily),
          const SizedBox(width: 24),
          _buildMiniStat('已完成', done, ModuleColors.success),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(fontSize: 13, color: Color(0xFF757575))),
        Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _FlagCard extends ConsumerStatefulWidget {
  const _FlagCard({required this.flag});
  final FlagItem flag;

  @override
  ConsumerState<_FlagCard> createState() => _FlagCardState();
}

class _FlagCardState extends ConsumerState<_FlagCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.flag;
    ref.watch(flagNotifierProvider);
    final progress = f.targetValue > 0 ? f.currentValue / f.targetValue : 0.0;
    final reachedMilestones = f.milestones.where((m) => m.isReached).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(f.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                      if (f.deadline != null)
                        Text(
                          '${f.deadline!.year}.${f.deadline!.month}.${f.deadline!.day}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                        ),
                      const SizedBox(width: 8),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: const Color(0xFF9E9E9E)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(ModuleColors.daily),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${f.currentValue.toInt()}/${f.targetValue.toInt()} ${f.unit ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                      const Spacer(),
                      Text('${(progress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ModuleColors.daily)),
                    ],
                  ),
                  if (f.milestones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('里程碑 $reachedMilestones/${f.milestones.length}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && f.milestones.isNotEmpty)
            _buildMilestones(f.flagId, f.milestones),
        ],
      ),
    );
  }

  Widget _buildMilestones(String flagId, List<MilestoneItem> milestones) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: milestones.map((m) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(flagNotifierProvider.notifier).toggleMilestone(flagId, m.milestoneId);
              },
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: m.isReached ? ModuleColors.daily : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: m.isReached ? ModuleColors.daily : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: m.isReached
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(m.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: m.isReached ? const Color(0xFF616161) : const Color(0xFF9E9E9E),
                          decoration: m.isReached ? TextDecoration.lineThrough : null,
                        )),
                  ),
                  if (m.targetValue != null)
                    Text('${m.targetValue!.toInt()} ${widget.flag.unit ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
