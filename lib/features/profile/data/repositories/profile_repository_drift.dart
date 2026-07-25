import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/system_bootstrap.dart';
import 'profile_repository.dart';

/// [ProfileRepository] 的 Drift 实现：档案 SQL 集中于此。系统用户 `user-001`
/// 由 [SystemBootstrap] 启动时确保（UserProfile.userId 有 FK 到 UserAccounts）。
class ProfileRepositoryDrift implements ProfileRepository {
  ProfileRepositoryDrift(this._db);

  final AppDatabase _db;

  @override
  Stream<UserProfileData?> watchProfile() =>
      (_db.select(_db.userProfile)..where((t) => t.userId.equals(systemUserId)))
          .watchSingleOrNull();

  @override
  Future<UserProfileData?> getProfile() =>
      (_db.select(_db.userProfile)..where((t) => t.userId.equals(systemUserId)))
          .getSingleOrNull();

  @override
  Future<void> upsertProfile({
    String? gender,
    double? heightCm,
    double? weightKg,
    DateTime? birthDate,
    String? motto,
  }) async {
    // Value.absent() 的列在 upsert 的 DO UPDATE 中不被触碰 → 传 null 不覆盖旧值。
    await _db.into(_db.userProfile).insertOnConflictUpdate(
          UserProfileCompanion(
            userId: Value(systemUserId),
            gender: gender != null ? Value(gender) : const Value.absent(),
            heightCm: heightCm != null ? Value(heightCm) : const Value.absent(),
            weightKg: weightKg != null ? Value(weightKg) : const Value.absent(),
            birthDate:
                birthDate != null ? Value(birthDate) : const Value.absent(),
            motto: (motto != null && motto.isNotEmpty)
                ? Value(motto)
                : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}

/// Repository 的 Riverpod 入口；presentation 依赖此接口。
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryDrift(ref.read(databaseProvider));
});

/// 当前档案流。
final profileProvider = StreamProvider<UserProfileData?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});
