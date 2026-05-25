import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/crypto/secure_vault_cipher.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/profile_providers.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(secureDocumentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('证件资产库'), backgroundColor: const Color(0xFFF8F9FA)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final doc = docs[i];
          final daysLeft = doc.expiryDate.difference(DateTime.now()).inDays;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                    Text(daysLeft > 0 ? '剩余 $daysLeft 天' : '已到期', style: TextStyle(fontSize: 12, color: daysLeft <= 45 ? ModuleColors.warning : const Color(0xFF9E9E9E))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('号码：${SecureVaultCipher.decrypt(doc.encryptedValue)}', style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
                const SizedBox(height: 4),
                Text('到期：${doc.expiryDate.year}-${doc.expiryDate.month}-${doc.expiryDate.day}', style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addDocument),
        child: const Icon(Icons.add),
      ),
    );
  }
}
