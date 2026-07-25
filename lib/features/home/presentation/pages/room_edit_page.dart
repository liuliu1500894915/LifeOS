import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/room_providers.dart';
import '../widgets/room_scene.dart';

/// 装修模式：在真实房间背景上摆放固定资产。
///
/// 摆件来源是财务模块勾选了「在虚拟房间中展示」的固定资产（`projectToRoom`），
/// 位置/缩放/层级经 `RoomRepository` 持久化到 `RoomFurniturePlacement`。
class RoomEditPage extends ConsumerWidget {
  const RoomEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(roomAssetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('装修模式'),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final items = assetsAsync.valueOrNull ?? const <RoomAssetItem>[];
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: RoomScene(isNight: false),
                      ),
                      for (final item in items)
                        _EditableAsset(
                          key: ValueKey(item.assetId),
                          item: item,
                          roomWidth: w,
                          roomHeight: h,
                        ),
                      if (assetsAsync.hasValue && items.isEmpty)
                        const Positioned.fill(child: _EmptyHint()),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildHintBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _buildToolChip(Icons.open_with, '拖拽'),
          const SizedBox(width: 8),
          _buildToolChip(Icons.zoom_out_map, '缩放'),
          const SizedBox(width: 8),
          _buildToolChip(Icons.layers_outlined, '双击置顶'),
        ],
      ),
    );
  }

  Widget _buildToolChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ModuleColors.home),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
        ],
      ),
    );
  }

  Widget _buildHintBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ModuleColors.home.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '拖动摆件调整位置，双击置顶，滑杆缩放 —— 改动会自动保存。'
          '在「财务 → 固定资产库」新增资产并开启「在虚拟房间中展示」即可加入房间。',
          style: TextStyle(fontSize: 12, color: Color(0xFF616161), height: 1.5),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(228),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '还没有可摆放的资产\n去「财务 → 固定资产库」添加，并开启「在虚拟房间中展示」',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Color(0xFF6D5B4A), height: 1.6),
        ),
      ),
    );
  }
}

/// 装修模式下的可编辑摆件：拖动 / 双击置顶 / 滑杆缩放，全部落库。
class _EditableAsset extends ConsumerStatefulWidget {
  const _EditableAsset({
    super.key,
    required this.item,
    required this.roomWidth,
    required this.roomHeight,
  });

  final RoomAssetItem item;
  final double roomWidth;
  final double roomHeight;

  @override
  ConsumerState<_EditableAsset> createState() => _EditableAssetState();
}

class _EditableAssetState extends ConsumerState<_EditableAsset> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visual = assetVisual(item.iconId);
    final left = item.posX * widget.roomWidth + _drag.dx;
    final top = item.posY * widget.roomHeight + _drag.dy;
    final repo = ref.read(roomRepositoryProvider);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (_) => repo.bringToFront(item.assetId),
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        onPanEnd: (_) {
          repo.moveAsset(
            item.assetId,
            left / widget.roomWidth,
            top / widget.roomHeight,
          );
          setState(() => _drag = Offset.zero);
        },
        onDoubleTap: () => repo.bringToFront(item.assetId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: item.scale,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: visual.color.withAlpha(90)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(visual.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.assetName,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF5D4B3A),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              width: 92,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: item.scale.clamp(0.6, 1.8),
                  min: 0.6,
                  max: 1.8,
                  activeColor: visual.color,
                  onChanged: (v) => repo.scaleAsset(item.assetId, v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
