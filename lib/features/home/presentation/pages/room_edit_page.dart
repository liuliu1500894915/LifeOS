import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/room_providers.dart';

class RoomEditPage extends ConsumerWidget {
  const RoomEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final furniture = ref.watch(roomFurnitureProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('装修模式'),
        backgroundColor: const Color(0xFFF8F9FA),
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _RoomGrid()),
                  for (final item in furniture)
                    _EditableFurniture(item: item),
                ],
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
          _buildToolChip(Icons.layers_outlined, '图层'),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF616161))),
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
          '长按家具拖动位置，双击置顶，滑杆缩放。骨骼动画与幸福/病态特效将在接入素材后启用。',
          style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
        ),
      ),
    );
  }
}

class _RoomGrid extends StatelessWidget {
  const _RoomGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomGridPainter(),
    );
  }
}

class _RoomGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(28)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EditableFurniture extends ConsumerWidget {
  const _EditableFurniture({required this.item});

  final RoomFurnitureItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      left: item.posX,
      top: item.posY,
      child: GestureDetector(
        onPanUpdate: (details) => ref.read(roomFurnitureNotifierProvider.notifier).move(item.placementId, details.delta),
        onDoubleTap: () => ref.read(roomFurnitureNotifierProvider.notifier).bringToFront(item.placementId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: item.scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.color.withAlpha(24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.color.withAlpha(80)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 92,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: item.scale,
                  min: 0.6,
                  max: 1.8,
                  activeColor: item.color,
                  onChanged: (value) => ref.read(roomFurnitureNotifierProvider.notifier).setScale(item.placementId, value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
