import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 瞬间照片的磁盘文件管理（P4-1）。
///
/// DB 只存路径、不存二进制（蓝图 §D）：用户拍照/选图得到的 `XFile` 在系统临时缓存
/// 里，本类把它拷入 App 文档目录的持久子目录 `moments/`，返回绝对路径入库。
/// 删瞬间时由 Notifier 拿到路径列表后调 [deleteFiles] best-effort 清理 —— 文件可能
/// 因迁移/外部删除已不在，故忽略「文件不存在」错误（蓝图 §3 允许 best-effort 清理）。
class MomentPhotoStore {
  static const subDir = 'moments';

  Future<Directory> _targetDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, subDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 把一张已选/已拍的图片拷入 `moments/`，返回持久绝对路径。
  /// 保留原扩展名；无扩展名时按 JPEG 存（image_picker 默认 JPEG）。
  Future<String> copyToAppDocs(XFile source) async {
    final dir = await _targetDir();
    final ext = p.extension(source.path).toLowerCase();
    final filename = '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}';
    final destPath = p.join(dir.path, filename);
    // 用 readAsBytes + writeAsBytes（cross_file 的 copyTo 在部分版本不可用，
    // 且本写入路径对相册/相机来源同样可靠）。
    final bytes = await source.readAsBytes();
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  /// best-effort 删除一批磁盘照片文件：忽略「不存在」错误，其它异常上抛。
  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } on FileSystemException {
          // 文件可能已被外部删除 —— 忽略，DB 行已是真相。
        }
      }
    }
  }
}

final momentPhotoStoreProvider = Provider<MomentPhotoStore>((ref) {
  return MomentPhotoStore();
});
