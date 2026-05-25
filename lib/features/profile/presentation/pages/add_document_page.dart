import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/secure_vault_cipher.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/profile_providers.dart';

class AddDocumentPage extends ConsumerStatefulWidget {
  const AddDocumentPage({super.key});

  @override
  ConsumerState<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends ConsumerState<AddDocumentPage> {
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('添加证件'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field(_titleController, '证件名称'),
            const SizedBox(height: 12),
            _field(_numberController, '证件号码'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('到期日：${_expiryDate.year}-${_expiryDate.month}-${_expiryDate.day}'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ModuleColors.analytics.withAlpha(12), borderRadius: BorderRadius.circular(12)),
              child: const Text('OCR 扫描面板占位：接入 ML Kit 后可从相机或相册提取号码与日期。', style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _save() {
    if (_titleController.text.trim().isEmpty || _numberController.text.trim().isEmpty) return;
    ref.read(secureDocumentsNotifierProvider.notifier).addDocument(
      SecureDocumentItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'OTHER',
        title: _titleController.text.trim(),
        encryptedValue: SecureVaultCipher.encrypt(_numberController.text.trim()),
        expiryDate: _expiryDate,
      ),
    );
    Navigator.of(context).pop();
  }
}
