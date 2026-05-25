import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/security_providers.dart';

class BiometricGate extends ConsumerWidget {
  const BiometricGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(securityGateProvider);
    if (unlocked) return child;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('安全验证'), backgroundColor: const Color(0xFFF8F9FA)),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: ModuleColors.success.withAlpha(18), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.face_retouching_natural, size: 36, color: ModuleColors.success),
              ),
              const SizedBox(height: 16),
              const Text('Face ID 路由拦截器', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('当前先用本地模拟验证。后续可接 local_auth 的真实生物识别。', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF616161))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => ref.read(securityGateProvider.notifier).unlock(),
                  style: ElevatedButton.styleFrom(backgroundColor: ModuleColors.profile),
                  child: const Text('验证进入', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
