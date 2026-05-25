import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomFurnitureItem {
  final String placementId;
  final String assetId;
  final String name;
  final IconData icon;
  final double posX;
  final double posY;
  final double scale;
  final int zIndex;
  final bool isVisible;
  final Color color;

  const RoomFurnitureItem({
    required this.placementId,
    required this.assetId,
    required this.name,
    required this.icon,
    required this.posX,
    required this.posY,
    this.scale = 1,
    this.zIndex = 0,
    this.isVisible = true,
    required this.color,
  });

  RoomFurnitureItem copyWith({
    double? posX,
    double? posY,
    double? scale,
    int? zIndex,
    bool? isVisible,
  }) {
    return RoomFurnitureItem(
      placementId: placementId,
      assetId: assetId,
      name: name,
      icon: icon,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      color: color,
    );
  }
}

class RoomFurnitureNotifier extends StateNotifier<List<RoomFurnitureItem>> {
  RoomFurnitureNotifier() : super(_mockFurniture);

  void move(String placementId, Offset delta) {
    state = [
      for (final item in state)
        if (item.placementId == placementId)
          item.copyWith(posX: item.posX + delta.dx, posY: item.posY + delta.dy)
        else
          item,
    ];
  }

  void setScale(String placementId, double scale) {
    state = [
      for (final item in state)
        if (item.placementId == placementId)
          item.copyWith(scale: scale.clamp(0.6, 1.8))
        else
          item,
    ];
  }

  void bringToFront(String placementId) {
    final maxZ = state.fold<int>(0, (m, i) => i.zIndex > m ? i.zIndex : m);
    state = [
      for (final item in state)
        if (item.placementId == placementId)
          item.copyWith(zIndex: maxZ + 1)
        else
          item,
    ];
  }

  static const _mockFurniture = [
    RoomFurnitureItem(
      placementId: 'f1',
      assetId: 'chair-001',
      name: '椅子',
      icon: Icons.chair,
      posX: 220,
      posY: 180,
      scale: 1.0,
      zIndex: 1,
      color: Color(0xFF2196F3),
    ),
    RoomFurnitureItem(
      placementId: 'f2',
      assetId: 'speaker-001',
      name: '音响',
      icon: Icons.speaker,
      posX: 40,
      posY: 40,
      scale: 0.9,
      zIndex: 2,
      color: Color(0xFF7C5CFC),
    ),
    RoomFurnitureItem(
      placementId: 'f3',
      assetId: 'plant-001',
      name: '绿植',
      icon: Icons.local_florist,
      posX: 260,
      posY: 60,
      scale: 1.1,
      zIndex: 0,
      color: Color(0xFF2EBD85),
    ),
  ];
}

final roomFurnitureNotifierProvider =
    StateNotifierProvider<RoomFurnitureNotifier, List<RoomFurnitureItem>>((ref) {
  return RoomFurnitureNotifier();
});

final roomFurnitureProvider = Provider<List<RoomFurnitureItem>>((ref) {
  final items = ref.watch(roomFurnitureNotifierProvider);
  final visible = items.where((i) => i.isVisible).toList();
  visible.sort((a, b) => a.zIndex.compareTo(b.zIndex));
  return visible;
});
