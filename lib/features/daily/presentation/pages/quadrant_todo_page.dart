import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/daily_providers.dart';
import '../widgets/todo_edit_drawer.dart';

class QuadrantTodoPage extends ConsumerStatefulWidget {
  const QuadrantTodoPage({super.key, this.initialQuadrant});
  final QuadrantType? initialQuadrant;

  @override
  ConsumerState<QuadrantTodoPage> createState() => _QuadrantTodoPageState();
}

class _QuadrantTodoPageState extends ConsumerState<QuadrantTodoPage> {
  late QuadrantType? _filterQuadrant;

  @override
  void initState() {
    super.initState();
    _filterQuadrant = widget.initialQuadrant;
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(quadrantTodoProvider);
    final incomplete = todos.where((t) => !t.isCompleted).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_filterQuadrant != null
            ? '${_filterQuadrant!.shortLabel}. ${_filterQuadrant!.label}'
            : '四象限工作台'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildCompletionSummary(todos),
          _buildQuadrantTabs(),
          Expanded(
            child: _filterQuadrant != null
                ? _buildSingleQuadrant(incomplete)
                : _buildAllQuadrants(incomplete),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditDrawer(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCompletionSummary(List<TodoItem> todos) {
    final done = todos.where((t) => t.isCompleted).length;
    final total = todos.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text('已完成 $done/$total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? done / total : 0,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(ModuleColors.daily),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip(null, '全部'),
            const SizedBox(width: 6),
            ...QuadrantType.values.map((q) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildTabChip(q, '${q.shortLabel}. ${q.label}'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(QuadrantType? q, String label) {
    final selected = _filterQuadrant == q;
    final color = q?.color ?? ModuleColors.daily;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _filterQuadrant = q);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleQuadrant(List<TodoItem> incomplete) {
    final items = incomplete.where((t) => t.quadrant == _filterQuadrant).toList();
    if (items.isEmpty) {
      return Center(
        child: Text('暂无任务', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
      );
    }
    return DragTarget<TodoItem>(
      onAcceptWithDetails: (details) => _moveTodo(details.data, _filterQuadrant!),
      builder: (context, candidate, rejected) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _TodoCard(
            todo: items[i],
            onTap: () => _openEditDrawer(items[i]),
          ),
        );
      },
    );
  }

  Widget _buildAllQuadrants(List<TodoItem> incomplete) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: QuadrantType.values.length,
      itemBuilder: (_, index) {
        final q = QuadrantType.values[index];
        final items = incomplete.where((t) => t.quadrant == q).toList();
        return _QuadrantSection(
          quadrant: q,
          items: items,
          onTodoTap: (todo) => _openEditDrawer(todo),
          onDragTo: (todo, target) => _moveTodo(todo, target),
        );
      },
    );
  }

  void _moveTodo(TodoItem todo, QuadrantType target) {
    HapticFeedback.mediumImpact();
    ref.read(todoNotifierProvider.notifier).moveQuadrant(todo.todoId, target);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已移至${target.shortLabel}象限'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEditDrawer(TodoItem? todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TodoEditDrawer(todo: todo),
    );
  }
}

class _QuadrantSection extends StatelessWidget {
  const _QuadrantSection({
    required this.quadrant,
    required this.items,
    required this.onTodoTap,
    required this.onDragTo,
  });

  final QuadrantType quadrant;
  final List<TodoItem> items;
  final void Function(TodoItem) onTodoTap;
  final void Function(TodoItem, QuadrantType) onDragTo;

  @override
  Widget build(BuildContext context) {
    final color = quadrant.color;
    return DragTarget<TodoItem>(
      onAcceptWithDetails: (details) => onDragTo(details.data, quadrant),
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? color.withAlpha(15) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: candidate.isNotEmpty ? Border.all(color: color.withAlpha(60)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(color),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('暂无任务', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
                )
              else
                ...items.map((todo) => _TodoCard(
                  todo: todo,
                  onTap: () => onTodoTap(todo),
                  quadrantColor: color,
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
            child: Center(
              child: Text(quadrant.shortLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Text(quadrant.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${items.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todo, required this.onTap, this.quadrantColor});

  final TodoItem todo;
  final VoidCallback onTap;
  final Color? quadrantColor;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<TodoItem>(
      data: todo,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (quadrantColor ?? ModuleColors.daily).withAlpha(60)),
          ),
          child: Text(todo.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildInner()),
      child: GestureDetector(onTap: onTap, child: _buildInner()),
    );
  }

  Widget _buildInner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(todo.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            '${todo.targetDate.month}/${todo.targetDate.day}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (todo.delayCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: ModuleColors.quadrantA.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('延${todo.delayCount}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ModuleColors.quadrantA)),
            ),
          ],
        ],
      ),
    );
  }
}
