import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_capsule.dart';
import '../../domain/pet_animation_state.dart';
import '../providers/home_providers.dart';
import '../providers/room_providers.dart';
import '../widgets/drink_drawer.dart';
import '../widgets/feed_drawer.dart';
import '../widgets/pet_character.dart';
import '../widgets/rest_drawer.dart';
import '../widgets/room_scene.dart';
import '../widgets/today_snapshot.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    final roomHeight = (screenHeight * 0.38).clamp(240.0, 360.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 12),
              _buildPetRoom(context, ref, roomHeight),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 12),
              _buildRoomActions(context),
              const SizedBox(height: 12),
              _buildHealthEntry(context),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TodaySnapshot(),
              ),
            ],
          ),
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

  Widget _buildPetRoom(BuildContext context, WidgetRef ref, double roomHeight) {
    final petStatus = ref.watch(petStatusProvider);
    // 固定资产投影：财务页勾选「在虚拟房间中展示」的资产会出现在房间里。
    final assets =
        ref.watch(roomAssetsProvider).valueOrNull ?? const <RoomAssetItem>[];
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;
    final moodTint = petStatus.overallStatusLevel == 'CRITICAL'
        ? ModuleColors.statusCritical
        : null;

    return Container(
      height: roomHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final petSize = math.min(h * 0.52, 165.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RoomScene(isNight: isNight, moodTint: moodTint),
              ),
              // 资产摆件（可拖动，位置持久化）
              for (final item in assets)
                _RoomAssetPiece(
                  key: ValueKey(item.assetId),
                  item: item,
                  roomWidth: w,
                  roomHeight: h,
                ),
              // 宠物：站在地毯中央
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.86 - petSize * 0.90,
                child: Center(
                  child: PetCharacter(
                    width: petSize,
                    height: petSize,
                    animationState:
                        PetAnimationMapper.fromVitals(petStatus.vitals),
                    hydrationLevel: petStatus.hydrationPoints,
                    energyLevel: petStatus.energyPoints,
                    moodLevel: petStatus.moodPoints,
                    bodyShapeLevel: petStatus.bodyShapePoints,
                  ),
                ),
              ),
            ],
          );
        },
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
            // P5-1：运动入口指向健康 ExercisePage（ExerciseLog 为唯一真相），
            // 不再开宠物侧独立运动抽屉。
            onTap: () => context.push(AppRoutes.exercise),
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

  // 健康饮食入口（P2-3）。health 模块目前无独立 tab，从主页 life-hub 进入。
  Widget _buildHealthEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.homeHealth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF7043).withAlpha(20),
                const Color(0xFFFF7043).withAlpha(45),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu, color: Color(0xFFFF7043), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('健康饮食', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                    Text('记录每餐摄入与营养', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFFF7043)),
            ],
          ),
        ),
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

/// 房间里的一件资产摆件：可拖动摆放，松手后位置写入 DB。
///
/// 位置用归一化坐标（0~1）存储，房间尺寸变化时摆件相对位置不变。
class _RoomAssetPiece extends ConsumerStatefulWidget {
  const _RoomAssetPiece({
    super.key,
    required this.item,
    required this.roomWidth,
    required this.roomHeight,
  });

  final RoomAssetItem item;
  final double roomWidth;
  final double roomHeight;

  @override
  ConsumerState<_RoomAssetPiece> createState() => _RoomAssetPieceState();
}

class _RoomAssetPieceState extends ConsumerState<_RoomAssetPiece> {
  /// 拖拽过程中的临时像素偏移；松手写库后清零（届时流已带来新位置）。
  Offset _drag = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visual = assetVisual(item.iconId);
    final size = 46.0 * item.scale;
    final left = item.posX * widget.roomWidth + _drag.dx;
    final top = item.posY * widget.roomHeight + _drag.dy;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _dragging = true);
          ref.read(roomRepositoryProvider).bringToFront(item.assetId);
        },
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        onPanEnd: (_) {
          // left/top 已含拖拽偏移；换算回归一化坐标写库。
          ref.read(roomRepositoryProvider).moveAsset(
                item.assetId,
                left / widget.roomWidth,
                top / widget.roomHeight,
              );
          setState(() {
            _drag = Offset.zero;
            _dragging = false;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _dragging ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: visual.color.withAlpha(90)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(_dragging ? 60 : 30),
                      blurRadius: _dragging ? 10 : 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(visual.emoji,
                      style: TextStyle(fontSize: size * 0.52)),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(70),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.assetName,
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
