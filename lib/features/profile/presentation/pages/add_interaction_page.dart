import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_providers.dart';

class AddInteractionPage extends ConsumerStatefulWidget {
  const AddInteractionPage({super.key});

  @override
  ConsumerState<AddInteractionPage> createState() => _AddInteractionPageState();
}

class _AddInteractionPageState extends ConsumerState<AddInteractionPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(relationshipProvider);
    _selectedId ??= items.isNotEmpty ? items.first.id : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('新增交往日志'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedId,
            underline: const SizedBox.shrink(),
            items: items.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
            onChanged: (value) => setState(() => _selectedId = value),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_selectedId == null) return;
    ref.read(relationshipNotifierProvider.notifier).logInteraction(_selectedId!);
    Navigator.of(context).pop();
  }
}
