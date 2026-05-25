import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/number_keyboard.dart';
import '../../../../../features/finance/presentation/providers/finance_providers.dart';
import '../providers/home_providers.dart';

const _drinkColor = Color(0xFF42A5F5);

enum _DrinkInputField { amount, calories, cost }

class DrinkDrawer extends ConsumerStatefulWidget {
  const DrinkDrawer({super.key});

  @override
  ConsumerState<DrinkDrawer> createState() => _DrinkDrawerState();
}

class _DrinkDrawerState extends ConsumerState<DrinkDrawer> {
  DrinkType _drinkType = DrinkType.water;
  _DrinkInputField _activeField = _DrinkInputField.amount;
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
          children: [
            _buildDragHandle(),
            Flexible(
              child: SingleChildScrollView(
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
                    _buildInputTile(
                      label: '饮水量',
                      value: _amount,
                      unit: 'ml',
                      field: _DrinkInputField.amount,
                    ),
                    if (_drinkType == DrinkType.beverage) ...[
                      const SizedBox(height: 8),
                      _buildInputTile(
                        label: '卡路里',
                        value: _calories,
                        unit: 'kcal',
                        field: _DrinkInputField.calories,
                      ),
                      const SizedBox(height: 8),
                      _buildInputTile(
                        label: '金额',
                        value: _cost,
                        unit: '元',
                        field: _DrinkInputField.cost,
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            NumberKeyboard(
              showDecimal: true,
              onKeyPressed: _onKeyPressed,
              onBackspace: _onBackspace,
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
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double currentMl, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _drinkColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.water_drop, size: 18, color: _drinkColor),
            ),
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
                _activeField = _DrinkInputField.amount;
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF9E9E9E),
                  ),
                ),
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
              setState(() {
                _activeField = _DrinkInputField.amount;
                _amount = cup.$2.toString();
              });
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
                child: Text(
                  cup.$1,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _drinkColor),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputTile({
    required String label,
    required String value,
    required String unit,
    required _DrinkInputField field,
  }) {
    final selected = _activeField == field;
    final displayValue = value.isEmpty ? '0' : value;
    return GestureDetector(
      onTap: () => setState(() => _activeField = field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _drinkColor.withAlpha(8) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _drinkColor : Colors.transparent,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF616161))),
            const Spacer(),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: field == _DrinkInputField.amount ? 28 : 18,
                fontWeight: FontWeight.w600,
                color: _drinkColor,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }

  void _onKeyPressed(String key) {
    setState(() {
      if (_activeField == _DrinkInputField.amount) {
        _amount = _appendValue(_amount, key, 6);
      } else if (_activeField == _DrinkInputField.calories) {
        _calories = _appendValue(_calories, key, 5);
      } else {
        _cost = _appendValue(_cost, key, 6);
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_activeField == _DrinkInputField.amount) {
        _amount = _removeLast(_amount);
      } else if (_activeField == _DrinkInputField.calories) {
        _calories = _removeLast(_calories);
      } else {
        _cost = _removeLast(_cost);
      }
    });
  }

  String _appendValue(String current, String key, int maxLength) {
    if (current.length >= maxLength) return current;
    if (key == '.' && current.contains('.')) return current;
    if (current == '0' && key != '.') return key;
    return current + key;
  }

  String _removeLast(String current) {
    if (current.isEmpty) return current;
    return current.substring(0, current.length - 1);
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
        associatedCost: _drinkType == DrinkType.beverage ? (double.tryParse(_cost) ?? 0) : 0,
        remark: _drinkType == DrinkType.beverage && _calories.isNotEmpty ? '${_calories}kcal' : null,
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
