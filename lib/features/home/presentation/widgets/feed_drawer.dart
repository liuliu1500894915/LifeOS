import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/number_keyboard.dart';
import '../providers/home_providers.dart';

const _feedColor = Color(0xFFFF7043);

class FeedDrawer extends ConsumerStatefulWidget {
  const FeedDrawer({super.key});

  @override
  ConsumerState<FeedDrawer> createState() => _FeedDrawerState();
}

class _FeedDrawerState extends ConsumerState<FeedDrawer> {
  final _searchController = TextEditingController();
  String _calories = '';
  String? _selectedFood;

  static const _quickFoods = [
    ('米饭🍚', '米饭', 230),
    ('面条🍜', '面条', 280),
    ('沙拉🥗', '沙拉', 150),
    ('鸡胸肉🍗', '鸡胸肉', 165),
    ('牛奶🥛', '牛奶', 120),
    ('咖啡☕', '咖啡', 80),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  _buildQuickFoods(),
                  const SizedBox(height: 12),
                  _buildCameraButton(),
                  const SizedBox(height: 12),
                  _buildCalorieDisplay(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            NumberKeyboard(
              showDecimal: true,
              onKeyPressed: (key) {
                setState(() {
                  if (_calories.length >= 6) return;
                  if (key == '.' && _calories.contains('.')) return;
                  if (_calories == '0' && key != '.') _calories = '';
                  _calories += key;
                });
              },
              onBackspace: () {
                setState(() {
                  if (_calories.isNotEmpty) _calories = _calories.substring(0, _calories.length - 1);
                });
              },
              onConfirm: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: _feedColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.restaurant, size: 18, color: _feedColor)),
        const SizedBox(width: 10),
        const Text('投喂记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: '搜索食物名称...',
          hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
          prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF9E9E9E)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildQuickFoods() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _quickFoods.map((item) {
        final selected = _selectedFood == item.$2;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedFood = item.$2;
              _calories = item.$3.toString();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? _feedColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(item.$1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF616161))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('拍照识别功能开发中'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF9E9E9E)),
            SizedBox(width: 6),
            Text('拍照识别', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieDisplay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text('卡路里', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _calories.isEmpty ? '0' : _calories,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: _feedColor, letterSpacing: 1),
          ),
          const SizedBox(width: 4),
          const Text('kcal', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  void _save() {
    if (_calories.isEmpty) return;
    ref.read(actionLogNotifierProvider.notifier).addAction(
      PetActionLog(
        logId: DateTime.now().millisecondsSinceEpoch.toString(),
        actionType: ActionType.feed,
        valueNumeric: double.tryParse(_calories) ?? 0,
        subCategory: _selectedFood,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }
}
