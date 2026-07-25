import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/cream_glass.dart';
import '../../../../core/widgets/status_capsule.dart';
import '../providers/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(secureDocumentsProvider);
    final memorials = ref.watch(memorialProvider);
    final relationships = ref.watch(relationshipProvider);
    final nearestDocDays = docs.isEmpty ? 0 : docs.map((d) => d.expiryDate.difference(DateTime.now()).inDays).reduce((a, b) => a < b ? a : b);
    final nearestMemorialDays = memorials.isEmpty ? 0 : memorials.map((m) => m.date.difference(DateTime.now()).inDays).reduce((a, b) => a < b ? a : b);
    final avgWarmth = relationships.isEmpty ? 0 : relationships.fold<int>(0, (s, r) => s + r.warmthScore) ~/ relationships.length;

    // 奶油玻璃：L1 光晕铺底。
    return Scaffold(
      backgroundColor: CreamGlass.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildProfileCard(context),
                  const SizedBox(height: 16),
                  _buildSecureMatrix(
                      context, nearestDocDays, nearestMemorialDays),
                  const SizedBox(height: 12),
                  _buildRelationshipEntry(
                      context, relationships.length, avgWarmth),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: ModuleColors.success.withAlpha(25), borderRadius: BorderRadius.circular(6)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, size: 12, color: ModuleColors.success),
              SizedBox(width: 4),
              Text('加密状态:全量保护', style: TextStyle(fontSize: 11, color: ModuleColors.success)),
            ],
          ),
        ),
        const Spacer(),
        const Text('个人中心', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, size: 20)),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.profileEdit),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: CreamGlass.surface, borderRadius: BorderRadius.circular(20), boxShadow: CreamGlass.cardShadow),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ModuleColors.profile, Color(0xFF78909C)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('陈晨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      StatusCapsule(label: '极客分身 v1.0', size: StatusCapsuleSize.small, color: ModuleColors.analytics),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('#Full-Stack  #数字游民  #CFA备考中', style: TextStyle(fontSize: 13, color: ModuleColors.analytics)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecureMatrix(BuildContext context, int nearestDocDays, int nearestMemorialDays) {
    return Row(
      children: [
        Expanded(
          child: _buildSecureCard(
            icon: Icons.folder_outlined,
            label: '证件资产库',
            alert: '最近到期剩 $nearestDocDays 天',
            isWarning: nearestDocDays <= 45,
            onTap: () => context.push(AppRoutes.documents),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSecureCard(
            icon: Icons.cake_outlined,
            label: '纪念日倒计时',
            alert: '最近纪念日还有 $nearestMemorialDays 天',
            isWarning: false,
            onTap: () => context.push(AppRoutes.memorials),
          ),
        ),
      ],
    );
  }

  Widget _buildSecureCard({
    required IconData icon,
    required String label,
    required String alert,
    required bool isWarning,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CreamGlass.surface, borderRadius: BorderRadius.circular(20), boxShadow: CreamGlass.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: isWarning ? ModuleColors.warning : ModuleColors.success),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(alert, style: TextStyle(fontSize: 12, color: isWarning ? ModuleColors.warning : ModuleColors.success, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipEntry(BuildContext context, int count, int avgWarmth) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.relationships),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CreamGlass.surface, borderRadius: BorderRadius.circular(20), boxShadow: CreamGlass.cardShadow),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: ModuleColors.home.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.people_outline, size: 22, color: ModuleColors.home),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('核心人际关系互动温度计', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('$count 位核心联系人 | 平均互动热度: $avgWarmth%', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}
