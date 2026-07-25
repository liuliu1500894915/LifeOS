import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/room_repository.dart';
import '../../data/repositories/room_repository_drift.dart';

export '../../data/repositories/room_repository.dart' show RoomAssetItem;
export '../../data/repositories/room_repository_drift.dart'
    show roomRepositoryProvider;

/// 房间摆件流：固定资产（`projectToRoom = true`）投影进宠物房间。
///
/// 此前这里是硬编码 mock（3 件假家具、不落库、资产的 `projectToRoom` 从未生效），
/// 现改为 Repository 的 `.watch()` 流 —— 财务页新增/勾选「在虚拟房间中展示」的
/// 资产会自动出现在房间里，拖动后的位置持久化。
final roomAssetsProvider = StreamProvider<List<RoomAssetItem>>((ref) {
  return ref.watch(roomRepositoryProvider).watchRoomAssets();
});

/// 摆件的视觉呈现（emoji + 主题色），按资产 `iconId` 映射。
///
/// iconId 取值与「新增资产」页的图标选择一致（laptop/chair/camera/…）。
/// 未知 id 回退到通用包裹图标，保证任何资产都能显示。
({String emoji, Color color}) assetVisual(String iconId) {
  switch (iconId) {
    case 'laptop':
      return (emoji: '💻', color: const Color(0xFF5C6BC0));
    case 'chair':
      return (emoji: '🪑', color: const Color(0xFF8D6E63));
    case 'camera':
      return (emoji: '📷', color: const Color(0xFF546E7A));
    case 'guitar':
      return (emoji: '🎸', color: const Color(0xFFD84315));
    case 'tablet':
      return (emoji: '📱', color: const Color(0xFF00897B));
    case 'car':
      return (emoji: '🚗', color: const Color(0xFFE53935));
    default:
      return (emoji: '📦', color: const Color(0xFF757575));
  }
}
