import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository_drift.dart';

/// 编辑档案页：设置性别 / 身高 / 体重 / 生日 / 一句话签名。
///
/// 之前此路由是占位空壳，导致运动页「档案未设体重，点此补全」点进来无处可填、
/// 健康 TDEE 目标也无从设置。本页补齐写入路径（[ProfileRepository.upsertProfile]）。
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  static const _accent = Color(0xFF4C6EF5);

  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();
  String? _gender; // MALE / FEMALE / OTHER
  DateTime? _birthDate;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final p = await ref.read(profileRepositoryProvider).getProfile();
    if (!mounted) return;
    setState(() {
      _gender = p?.gender;
      _birthDate = p?.birthDate;
      if (p?.heightCm != null) _heightCtrl.text = _trim(p!.heightCm!);
      if (p?.weightKg != null) _weightCtrl.text = _trim(p!.weightKg!);
      if (p?.motto != null) _mottoCtrl.text = p!.motto!;
      _loaded = true;
    });
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _mottoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).upsertProfile(
            gender: _gender,
            heightCm: double.tryParse(_heightCtrl.text.trim()),
            weightKg: double.tryParse(_weightCtrl.text.trim()),
            birthDate: _birthDate,
            motto: _mottoCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('档案已保存'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: '选择出生日期',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('编辑档案'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('保存',
                style: TextStyle(
                    color: _saving ? Colors.grey : _accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                const _Hint(
                    '身高、体重、生日、性别用于自动计算 TDEE 与运动消耗，建议如实填写。'),
                const SizedBox(height: 16),
                _label('性别'),
                _GenderPicker(
                  value: _gender,
                  onChanged: (g) => setState(() => _gender = g),
                  accent: _accent,
                ),
                const SizedBox(height: 20),
                _label('身高'),
                _numField(_heightCtrl, 'cm', '如 175'),
                const SizedBox(height: 20),
                _label('体重'),
                _numField(_weightCtrl, 'kg', '如 65'),
                const SizedBox(height: 20),
                _label('生日'),
                _DateField(
                  date: _birthDate,
                  onTap: _pickBirthDate,
                  accent: _accent,
                ),
                const SizedBox(height: 20),
                _label('一句话签名（可选）'),
                TextField(
                  controller: _mottoCtrl,
                  maxLength: 200,
                  decoration: _inputDecoration('记录此刻的心情或目标…'),
                ),
              ],
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF616161),
                fontWeight: FontWeight.w500)),
      );

  Widget _numField(TextEditingController c, String suffix, String hint) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: _inputDecoration(hint).copyWith(suffixText: suffix),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4C6EF5).withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF4C6EF5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF5C6BC0), height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  const _GenderPicker(
      {required this.value, required this.onChanged, required this.accent});
  final String? value;
  final ValueChanged<String?> onChanged;
  final Color accent;

  static const _opts = [('MALE', '男'), ('FEMALE', '女'), ('OTHER', '其他')];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in _opts) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == o.$1 ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: value == o.$1 ? accent : const Color(0xFFE0E0E0)),
                ),
                alignment: Alignment.center,
                child: Text(o.$2,
                    style: TextStyle(
                        color: value == o.$1 ? Colors.white : const Color(0xFF616161),
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          if (o != _opts.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.date, required this.onTap, required this.accent});
  final DateTime? date;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? '选择出生日期'
        : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: accent),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: date == null ? const Color(0xFF9E9E9E) : const Color(0xFF212121))),
          ],
        ),
      ),
    );
  }
}
