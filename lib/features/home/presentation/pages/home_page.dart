import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_capsule.dart';
import '../../domain/pet_animation_state.dart';
import '../providers/home_providers.dart';
import '../widgets/drink_drawer.dart';
import '../widgets/exercise_drawer.dart';
import '../widgets/feed_drawer.dart';
import '../widgets/pet_character.dart';
import '../widgets/rest_drawer.dart';
import '../widgets/today_snapshot.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 12),
            _buildPetRoom(context, ref),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 12),
            _buildRoomActions(context),
            const SizedBox(height: 12),
            const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TodaySnapshot())),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ModuleColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 12, color: ModuleColors.success),
                SizedBox(width: 4),
                Text('数据芯片已加密', style: TextStyle(fontSize: 11, color: ModuleColors.success)),
              ],
            ),
          ),
          const Spacer(),
          const Text('Life OS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(AppRoutes.petPanel),
            child: StatusCapsule(label: _statusLabel(ref.watch(petStatusProvider).overallStatusLevel), size: StatusCapsuleSize.small),
          ),
        ],
      ),
    );
  }

  Widget _buildPetRoom(BuildContext context, WidgetRef ref) {
    final petStatus = ref.watch(petStatusProvider);
    return Container(
      height: MediaQuery.of(context).size.height * 0.38,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Center(child: PetCharacter(
            animationState: PetAnimationMapper.fromVitals(petStatus.vitals),
            hydrationLevel: petStatus.hydrationPoints,
            energyLevel: petStatus.energyPoints,
            moodLevel: petStatus.moodPoints,
            bodyShapeLevel: petStatus.bodyShapePoints,
          )),
          Positioned(
            right: 20, bottom: 30,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: ModuleColors.daily.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.chair, size: 24, color: ModuleColors.daily),
            ),
          ),
          Positioned(
            left: 24, top: 20,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: ModuleColors.analytics.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.music_note, size: 22, color: ModuleColors.analytics),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: Icons.restaurant,
            label: '投喂',
            color: const Color(0xFFFF7043),
            onTap: () => _showSheet(context, const FeedDrawer()),
          ),
          _QuickActionButton(
            icon: Icons.water_drop,
            label: '喝水',
            color: const Color(0xFF42A5F5),
            onTap: () => _showSheet(context, const DrinkDrawer()),
          ),
          _QuickActionButton(
            icon: Icons.fitness_center,
            label: '运动',
            color: const Color(0xFF66BB6A),
            onTap: () => _showSheet(context, const ExerciseDrawer()),
          ),
          _QuickActionButton(
            icon: Icons.bed,
            label: '休息',
            color: const Color(0xFF7E57C2),
            onTap: () => _showSheet(context, const RestDrawer()),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, Widget drawer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => drawer,
    );
  }

  String _statusLabel(String level) => const {
    'EXCELLENT': '极佳',
    'GOOD': '良好',
    'NORMAL': '正常',
    'WARNING': '疲惫',
    'CRITICAL': '危险',
  }[level] ?? '正常';

  Widget _buildRoomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _TextButton(
              icon: Icons.design_services_outlined,
              label: '进入装修模式',
              onTap: () => context.push(AppRoutes.roomEdit),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TextButton(
              icon: Icons.share_outlined,
              label: '一键快照分享',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ModuleColors.home),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF616161))),
          ],
        ),
      ),
    );
  }
}
