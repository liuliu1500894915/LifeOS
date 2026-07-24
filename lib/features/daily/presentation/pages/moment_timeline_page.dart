import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/moment_providers.dart';
import '../widgets/moment_recorder_drawer.dart';

const _momentColor = ModuleColors.daily;

/// 生活瞬间时间线（P4-1）。读 [momentsWithPhotosProvider]（Drift `.watch()` 流），
/// 写库（记一条 / 删一条）后流自动重发，UI 自动刷新，无手动重查。
class MomentTimelinePage extends ConsumerWidget {
  const MomentTimelinePage({super.key});

  void _openRecorder(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MomentRecorderDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(momentsWithPhotosProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('生活瞬间'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '记录瞬间',
            onPressed: () => _openRecorder(context),
          ),
        ],
      ),
      body: moments.isEmpty
          ? _buildEmpty(context)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: moments.length,
              itemBuilder: (_, i) {
                final item = moments[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MomentCard(
                    item: item,
                    onDelete: () => _confirmDelete(context, ref, item),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRecorder(context),
        backgroundColor: _momentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_camera_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('还没有记录任何瞬间',
              style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 4),
          const Text('随手拍一张、写一句，留住今天',
              style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MomentWithPhotos item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个瞬间？'),
        content: const Text('照片与文字会一并删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(momentProvider.notifier).deleteMoment(item.moment.momentId);
    }
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.item, required this.onDelete});
  final MomentWithPhotos item;
  final VoidCallback onDelete;

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final m = item.moment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(_formatTime(m.loggedAt),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
              if (m.moodTag != null) ...[
                const SizedBox(width: 8),
                Text(m.moodTag!, style: const TextStyle(fontSize: 16)),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey.shade400),
              ),
            ],
          ),
          if (m.content != null && m.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.content!,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF424242))),
          ],
          if (item.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PhotoRow(paths: item.photoPaths),
          ],
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final display = paths.take(3).toList();
    final extra = paths.length - display.length;
    return Row(
      children: [
        for (int i = 0; i < display.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(display[i]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (i == 2 && extra > 0)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text(
                          '+$extra',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
