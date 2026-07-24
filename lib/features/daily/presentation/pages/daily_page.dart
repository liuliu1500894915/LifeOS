import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/daily_providers.dart';
import '../providers/moment_providers.dart';

class DailyPage extends ConsumerStatefulWidget {
  const DailyPage({super.key});

  @override
  ConsumerState<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends ConsumerState<DailyPage> {
  final _inboxController = TextEditingController();

  @override
  void dispose() {
    _inboxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(quadrantTodoProvider);
    final habits = ref.watch(todayHabitsProvider);
    final flags = ref.watch(flagListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildInbox(),
              const SizedBox(height: 16),
              _buildQuadrantMiniBoard(context, todos),
              const SizedBox(height: 16),
              _buildTodayHabits(context, habits),
              const SizedBox(height: 12),
              _buildFlagOverview(context, flags),
              const SizedBox(height: 12),
              _buildMomentCard(context),
              const SizedBox(height: 12),
              _buildReviewCard(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ModuleColors.success.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.backup_outlined, size: 12, color: ModuleColors.success),
              SizedBox(width: 4),
              Text('数据已增量备份', style: TextStyle(fontSize: 11, color: ModuleColors.success)),
            ],
          ),
        ),
        const Spacer(),
        const Text('行动中心', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: () => context.push(AppRoutes.reviewLog),
          icon: const Icon(Icons.archive_outlined, size: 20),
        ),
      ],
    );
  }

  Widget _buildInbox() {
    final inboxTodos = ref.watch(inboxTodoProvider);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, size: 20, color: ModuleColors.daily),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _inboxController,
                  onSubmitted: _onInboxSubmit,
                  decoration: const InputDecoration(
                    hintText: '闪电录入一句任务（如：19:00 去健身房）...',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const Text('回车', style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
            ],
          ),
        ),
        if (inboxTodos.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...inboxTodos.take(3).map((todo) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: ModuleColors.quadrantD, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(todo.title,
                      style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          )),
          GestureDetector(
            onTap: () => context.push(AppRoutes.quadrantTodo),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text('查看全部 →', style: TextStyle(fontSize: 12, color: ModuleColors.daily)),
            ),
          ),
        ],
      ],
    );
  }

  void _onInboxSubmit(String value) {
    if (value.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(todoNotifierProvider.notifier).addTodo(
      TodoItem(
        todoId: DateTime.now().millisecondsSinceEpoch.toString(),
        title: value.trim(),
        quadrant: QuadrantType.D,
        targetDate: DateTime.now(),
      ),
    );
    _inboxController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加: $value'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildQuadrantMiniBoard(BuildContext context, List<TodoItem> todos) {
    final incomplete = todos.where((t) => !t.isCompleted);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildQuadrantCell(
              'A. 重要·紧急',
              '${incomplete.where((t) => t.quadrant == QuadrantType.A).length}项待办',
              ModuleColors.quadrantA,
              () => context.push(AppRoutes.quadrantTodo, extra: QuadrantType.A),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildQuadrantCell(
              'B. 重要·不紧急',
              '${incomplete.where((t) => t.quadrant == QuadrantType.B).length}项待办',
              ModuleColors.quadrantB,
              () => context.push(AppRoutes.quadrantTodo, extra: QuadrantType.B),
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildQuadrantCell(
              'C. 紧急·不重要',
              '${incomplete.where((t) => t.quadrant == QuadrantType.C).length}项待办',
              ModuleColors.quadrantC,
              () => context.push(AppRoutes.quadrantTodo, extra: QuadrantType.C),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildQuadrantCell(
              'D. 不紧急·不重要',
              '${incomplete.where((t) => t.quadrant == QuadrantType.D).length}项待办',
              ModuleColors.quadrantD,
              () => context.push(AppRoutes.quadrantTodo, extra: QuadrantType.D),
            )),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => context.push(AppRoutes.quadrantTodo),
          child: const Align(
            alignment: Alignment.centerRight,
            child: Text('查看全部 →', style: TextStyle(fontSize: 12, color: ModuleColors.daily)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrantCell(String label, String detail, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHabits(BuildContext context, List<HabitItem> habits) {
    if (habits.isEmpty) return const SizedBox.shrink();
    final display = habits.take(2).toList();
    return Column(
      children: [
        ...display.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.habitDetail),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(h.habitIcon ?? '✅', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.habitName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        if (h.targetType == HabitTargetType.numeric && h.targetValue != null) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ((h.todayValue ?? 0) / h.targetValue!).clamp(0.0, 1.0),
                              backgroundColor: ModuleColors.daily.withAlpha(30),
                              valueColor: const AlwaysStoppedAnimation(ModuleColors.daily),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (h.streakDays > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 2),
                          Text('${h.streakDays}天',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                        ],
                      ),
                    ),
                  if (h.todayChecked)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ModuleColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('已打卡',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ModuleColors.success)),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
                ],
              ),
            ),
          ),
        )),
        if (habits.length > 2)
          GestureDetector(
            onTap: () => context.push(AppRoutes.habitDetail),
            child: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('查看更多习惯 →', style: TextStyle(fontSize: 12, color: ModuleColors.daily)),
            ),
          ),
      ],
    );
  }

  Widget _buildFlagOverview(BuildContext context, List<FlagItem> flags) {
    if (flags.isEmpty) return const SizedBox.shrink();
    final display = flags.take(2).toList();
    return Column(
      children: [
        ...display.map((f) {
          final progress = f.targetValue > 0 ? f.currentValue / f.targetValue : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.flagTimeline),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🚩', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: ModuleColors.daily.withAlpha(30),
                                    valueColor: const AlwaysStoppedAnimation(ModuleColors.daily),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${(progress * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
                  ],
                ),
              ),
            ),
          );
        }),
        if (flags.length > 2)
          GestureDetector(
            onTap: () => context.push(AppRoutes.flagTimeline),
            child: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('查看更多目标 →', style: TextStyle(fontSize: 12, color: ModuleColors.daily)),
            ),
          ),
      ],
    );
  }

  Widget _buildMomentCard(BuildContext context) {
    final todayCount = ref.watch(todayMomentCountProvider);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.momentTimeline),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ModuleColors.daily.withAlpha(15),
              ModuleColors.daily.withAlpha(35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('📸', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生活瞬间',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    todayCount > 0 ? '今日已记录 $todayCount 个瞬间' : '随手拍一张、写一句，留住今天',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.reviewEditor),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ModuleColors.daily.withAlpha(15),
              ModuleColors.daily.withAlpha(40),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '这一天就要结束了，点击开启今日结构化复盘日志吧。',
                style: TextStyle(fontSize: 14, color: Color(0xFF424242)),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}
