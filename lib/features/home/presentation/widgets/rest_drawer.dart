import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

const _restColor = Color(0xFF7E57C2);

class RestDrawer extends ConsumerStatefulWidget {
  const RestDrawer({super.key});

  @override
  ConsumerState<RestDrawer> createState() => _RestDrawerState();
}

class _RestDrawerState extends ConsumerState<RestDrawer> {
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;
  int _quality = 0;

  double get _sleepHours {
    if (_bedTime == null || _wakeTime == null) return 0;
    final bed = _bedTime!.hour + _bedTime!.minute / 60;
    var wake = _wakeTime!.hour + _wakeTime!.minute / 60;
    if (wake <= bed) wake += 24;
    return wake - bed;
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
                  const SizedBox(height: 16),
                  _buildTimeRow(),
                  if (_sleepHours > 0) ...[
                    const SizedBox(height: 12),
                    _buildDurationResult(),
                  ],
                  const SizedBox(height: 16),
                  _buildQualityRating(),
                  const SizedBox(height: 20),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              ),
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
        Container(width: 32, height: 32, decoration: BoxDecoration(color: _restColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bed, size: 18, color: _restColor)),
        const SizedBox(width: 10),
        const Text('睡眠登记', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTimeRow() {
    return Row(
      children: [
        Expanded(child: _buildTimePill(
          icon: Icons.bedtime,
          label: _bedTime != null ? '${_bedTime!.hour}:${_bedTime!.minute.toString().padLeft(2, '0')}' : '入睡时间',
          hasValue: _bedTime != null,
          onTap: _pickBedTime,
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade400),
        ),
        Expanded(child: _buildTimePill(
          icon: Icons.wb_sunny_outlined,
          label: _wakeTime != null ? '${_wakeTime!.hour}:${_wakeTime!.minute.toString().padLeft(2, '0')}' : '起床时间',
          hasValue: _wakeTime != null,
          onTap: _pickWakeTime,
        )),
      ],
    );
  }

  Widget _buildTimePill({required IconData icon, required String label, required bool hasValue, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasValue ? _restColor.withAlpha(10) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: hasValue ? _restColor : const Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: hasValue ? _restColor : const Color(0xFFBDBDBD)),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_restColor.withAlpha(20), _restColor.withAlpha(5)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.nightlight, size: 18, color: _restColor),
          const SizedBox(width: 6),
          const Text('睡眠时长', style: TextStyle(fontSize: 14, color: Color(0xFF616161))),
          const Spacer(),
          Text(_sleepHours.toStringAsFixed(1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _restColor)),
          const SizedBox(width: 4),
          const Text('小时', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildQualityRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('睡眠质量', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled = starIndex <= _quality;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _quality = starIndex);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: filled ? _restColor.withAlpha(20) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 20,
                    color: filled ? _restColor : Colors.grey.shade400,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: (_bedTime != null && _wakeTime != null) ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _restColor,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Future<void> _pickBedTime() async {
    final picked = await showTimePicker(context: context, initialTime: _bedTime ?? const TimeOfDay(hour: 23, minute: 0));
    if (picked != null) setState(() => _bedTime = picked);
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(context: context, initialTime: _wakeTime ?? const TimeOfDay(hour: 7, minute: 0));
    if (picked != null) setState(() => _wakeTime = picked);
  }

  void _save() {
    if (_bedTime == null || _wakeTime == null) return;
    ref.read(actionLogNotifierProvider.notifier).addAction(
      PetActionLog(
        logId: DateTime.now().millisecondsSinceEpoch.toString(),
        actionType: ActionType.rest,
        valueNumeric: _sleepHours,
        subjectiveScore: _quality,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }
}
