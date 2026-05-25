import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_providers.dart';

class AddMemorialPage extends ConsumerStatefulWidget {
  const AddMemorialPage({super.key});

  @override
  ConsumerState<AddMemorialPage> createState() => _AddMemorialPageState();
}

class _AddMemorialPageState extends ConsumerState<AddMemorialPage> {
  final _nameController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('新增纪念日'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: TextField(controller: _nameController, decoration: const InputDecoration(hintText: '纪念日名称', border: InputBorder.none, contentPadding: EdgeInsets.all(14))),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('日期：${_date.year}-${_date.month}-${_date.day}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    ref.read(memorialNotifierProvider.notifier).addMemorial(
      MemorialItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: _nameController.text.trim(), date: _date),
    );
    Navigator.of(context).pop();
  }
}
