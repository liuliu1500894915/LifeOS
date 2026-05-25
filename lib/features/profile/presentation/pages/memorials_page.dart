import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/profile_providers.dart';

class MemorialsPage extends ConsumerWidget {
  const MemorialsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memorials = ref.watch(memorialProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('纪念日'), backgroundColor: const Color(0xFFF8F9FA)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: memorials.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = memorials[i];
          final days = item.date.difference(DateTime.now()).inDays;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('倒计时 $days 天', style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
                ])),
                if (item.budget != null) Text('¥${item.budget!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addMemorial),
        child: const Icon(Icons.add),
      ),
    );
  }
}
