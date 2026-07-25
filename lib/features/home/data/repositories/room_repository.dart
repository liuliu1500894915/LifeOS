/// 房间里的一件资产摆件：固定资产（[AssetInventory]，`projectToRoom = true`）
/// 与其摆放信息（[RoomFurniturePlacement]）的组合。
///
/// 资产可能尚未有 placement 行（用户刚在财务页新增资产、还没摆过），此时
/// [placementId] 为 null、位置用确定性默认排布；首次拖动/缩放时才落库。
class RoomAssetItem {
  const RoomAssetItem({
    required this.assetId,
    required this.assetName,
    required this.iconId,
    required this.posX,
    required this.posY,
    this.placementId,
    this.scale = 1.0,
    this.zIndex = 0,
    this.isVisible = true,
  });

  final String? placementId;
  final String assetId;
  final String assetName;
  final String iconId;
  final double posX;
  final double posY;
  final double scale;
  final int zIndex;
  final bool isVisible;

  RoomAssetItem copyWith({
    double? posX,
    double? posY,
    double? scale,
    int? zIndex,
    bool? isVisible,
  }) {
    return RoomAssetItem(
      placementId: placementId,
      assetId: assetId,
      assetName: assetName,
      iconId: iconId,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// 宠物房间的资产摆件读写。
///
/// 此前房间家具是 `room_providers.dart` 里的硬编码 mock（3 件假家具、
/// StateNotifier 不落库），固定资产的 `projectToRoom` 字段也从未被使用 ——
/// 本 Repository 补上「资产 → 房间摆件」的真实投影与持久化。
abstract interface class RoomRepository {
  /// 房间摆件流：所有 `projectToRoom = true` 的资产 + 其摆放信息，按 zIndex 升序。
  Stream<List<RoomAssetItem>> watchRoomAssets();

  /// 移动摆件到 [posX]/[posY]（房间坐标系的归一化比例 0~1）。无 placement 则创建。
  Future<void> moveAsset(String assetId, double posX, double posY);

  /// 缩放摆件（0.6~1.8）。无 placement 则创建。
  Future<void> scaleAsset(String assetId, double scale);

  /// 把摆件提到最前（zIndex = 当前最大 + 1）。
  Future<void> bringToFront(String assetId);
}
