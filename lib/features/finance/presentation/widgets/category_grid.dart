import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../providers/finance_providers.dart';

class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.showManage = true,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool showManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(expenseCategoryListProvider);

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('加载分类中...', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)))),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: categories.length + (showManage ? 1 : 0),
          itemBuilder: (context, index) {
            if (showManage && index == categories.length) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showCategoryManager(context, ref);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 20, color: Color(0xFF9E9E9E)),
                      SizedBox(height: 4),
                      Text('管理', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                    ],
                  ),
                ),
              );
            }

            final cat = categories[index];
            final isSelected = cat.categoryId == selectedId;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelected(cat.categoryId);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withAlpha(20)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.categoryIcon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      cat.categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showCategoryManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CategoryManagerSheet(),
    );
  }
}

class _CategoryManagerSheet extends ConsumerStatefulWidget {
  const _CategoryManagerSheet();

  @override
  ConsumerState<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends ConsumerState<_CategoryManagerSheet> {
  final _nameCtl = TextEditingController();
  final _iconCtl = TextEditingController(text: '📦');
  bool _isIncome = false;

  static const _iconOptions = ['🍱', '🚗', '🎉', '💧', '🛒', '🏠', '🐱', '⚙️', '🔄', '💰', '🎁', '📈', '📦', '🎮', '💊', '📚', '✈️', '🏋️', '👶', '🐕'];

  @override
  void dispose() {
    _nameCtl.dispose();
    _iconCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoryListProvider);
    final incomeCategories = ref.watch(incomeCategoryListProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('管理支出类别', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (categories.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('支出类别', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF757575))),
                    ),
                    ...categories.map((cat) => _buildCategoryTile(cat)),
                    const SizedBox(height: 12),
                  ],
                  if (incomeCategories.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('收入类别', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF757575))),
                    ),
                    ...incomeCategories.map((cat) => _buildCategoryTile(cat)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('添加新类别', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                labelText: '类别名称',
                hintText: '如：咖啡',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _iconOptions.map((icon) {
                final selected = _iconCtl.text == icon;
                return GestureDetector(
                  onTap: () => setState(() => _iconCtl.text = icon),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primary.withAlpha(20) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                    ),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('收入类别', style: TextStyle(fontSize: 14)),
              value: _isIncome,
              onChanged: (v) => setState(() => _isIncome = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _addCategory,
                child: const Text('添加类别'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(ExpenseCategory cat) {
    return ListTile(
      dense: true,
      leading: Text(cat.categoryIcon, style: const TextStyle(fontSize: 22)),
      title: Text(cat.categoryName, style: const TextStyle(fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFBDBDBD)),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除类别'),
              content: Text('确定删除「${cat.categoryName}」吗？已有记录的类别ID不会被更新。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(categoryProvider.notifier).deleteCategory(cat.categoryId);
          }
        },
      ),
    );
  }

  Future<void> _addCategory() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入类别名称'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    try {
      await ref.read(categoryProvider.notifier).addCategory(
            name,
            _iconCtl.text,
            isIncome: _isIncome,
          );
      _nameCtl.clear();
      _iconCtl.text = '📦';
      setState(() => _isIncome = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('类别已添加'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
