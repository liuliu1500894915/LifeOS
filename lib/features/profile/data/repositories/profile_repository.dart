import 'package:life_os/core/database/app_database.dart';

/// 用户档案（`UserProfile`）读写。字段（性别/身高/体重/生日）是健康 TDEE 目标与
/// 运动消耗计算的输入，此前无写入路径，导致「点此补全体重」无处可填。
abstract interface class ProfileRepository {
  /// 当前系统用户的档案流；无档案时发 null。
  Stream<UserProfileData?> watchProfile();

  Future<UserProfileData?> getProfile();

  /// upsert 档案的可编辑字段。传 null 的字段保持不变（不覆盖为空），便于分步补全。
  Future<void> upsertProfile({
    String? gender, // MALE / FEMALE / OTHER
    double? heightCm,
    double? weightKg,
    DateTime? birthDate,
    String? motto,
  });
}
