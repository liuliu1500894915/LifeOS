import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/number_keyboard.dart';
import '../../../../../features/finance/presentation/providers/finance_providers.dart';

import '../providers/home_providers.dart';

const _drinkColor = Color(0xFF42A5F5);

class DrinkDrawer extends ConsumerStatefulWidget {
  const DrinkDrawer({super.key});

  @override
  ConsumerState<DrinkDrawer> createState() => _DrinkDrawerState();
}

class _DrinkDrawerState extends ConsumerState<DrinkDrawer> {
  DrinkType _drinkType = DrinkType.water;
  String _amount = '';
  String _calories = '';
  String _cost = '';

  static const _quickCups = [
    ('一杯 200ml', 200),
    ('大杯 350ml', 350),
    ('一瓶 500ml', 500),
  ];

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(todaySummaryProvider);
    final progress = (summary.waterMl / 2000).clamp(0.0, 1.0);

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
                  _buildHeader(summary.waterMl, progress),
                  const SizedBox(height: 12),
                  _buildTypeSwitch(),
                  const SizedBox(height: 12),
                  if (_drinkType == DrinkType.water) ...[
                    _buildQuickCups(),
                    const SizedBox(height: 12),
                  ],
                  _buildAmountDisplay(),
                  if (_drinkType == DrinkType.beverage) ...[
                    const SizedBox(height: 8),
                    _buildExtraRow('卡路里', _calories, 'kcal'),
                    const SizedBox(height: 6),
                    _buildExtraRow('金额', _cost, '元'),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            NumberKeyboard(
              showDecimal: true,
              onKeyPressed: (key) {
                setState(() {
                  if (_amount.length >= 6) return;
                  if (key == '.' && _amount.contains('.')) return;
                  if (_amount == '0' && key != '.') _amount = '';
                  _amount += key;
                });
              },
              onBackspace: () {
                setState(() {
                  if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
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

  Widget _buildHeader(double currentMl, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: _drinkColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.water_drop, size: 18, color: _drinkColor)),
            const SizedBox(width: 10),
            const Text('喝水记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${currentMl.toInt()}/2000ml', style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(_drinkColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSwitch() {
    return Row(
      children: DrinkType.values.map((t) {
        final selected = t == _drinkType;
        final label = t == DrinkType.water ? '纯水 💧' : '饮料 🥤';
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _drinkType = t;
                _amount = '';
                _calories = '';
                _cost = '';
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _drinkColor : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF9E9E9E))),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickCups() {
    return Row(
      children: _quickCups.map((cup) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _amount = cup.$2.toString());
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _drinkColor.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _drinkColor.withAlpha(40)),
              ),
              child: Center(
                child: Text(cup.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _drinkColor)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text('饮水量', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(
            _amount.isEmpty ? '0' : _amount,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: _drinkColor, letterSpacing: 1),
          ),
          const SizedBox(width: 4),
          const Text('ml', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildExtraRow(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          const Spacer(),
          Text(value.isEmpty ? '0' : value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _drinkColor)),
          const SizedBox(width: 4),
          Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  void _save() {
    if (_amount.isEmpty) return;
    final ml = double.tryParse(_amount) ?? 0;

    ref.read(actionLogNotifierProvider.notifier).addAction(
      PetActionLog(
        logId: DateTime.now().millisecondsSinceEpoch.toString(),
        actionType: ActionType.drink,
        valueNumeric: ml,
        subCategory: _drinkType == DrinkType.water ? 'water' : 'beverage',
        createdAt: DateTime.now(),
      ),
    );

    if (_drinkType == DrinkType.beverage) {
      final cost = double.tryParse(_cost) ?? 0;
      if (cost > 0) {
        ref.read(transactionNotifierProvider.notifier).addTransaction(
          TransactionItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            flowType: 'EXPENSE',
            amount: cost,
            categoryId: 'drink',
            categoryName: '饮品',
            accountName: '微信支付',
            remark: '含糖饮料',
            loggedAt: DateTime.now(),
          ),
        );
      }
    }

    Navigator.of(context).pop();
  }
}
