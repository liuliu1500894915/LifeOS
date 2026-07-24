import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/moment_providers.dart';

const _momentColor = ModuleColors.daily;

/// 可选心情（emoji + 名称）。moodTag 存 emoji 字符串入 DB，名称仅 UI 展示。
const _moodOptions = <(String emoji, String label)>[
  ('😊', '开心'),
  ('😌', '平静'),
  ('🥰', '幸福'),
  ('💪', '充实'),
  ('😴', '疲惫'),
  ('😔', '低落'),
  ('🔥', '兴奋'),
  ('🤔', '思考'),
];

/// 生活瞬间记录抽屉（P4-1）。底部弹层：拍照 / 多图相册 + 一段文字 + 心情 →
/// 写 LifeMoment + 多张 MomentPhoto(有序)。照片经 image_picker 取得后由
/// Repository 拷入 App 文档目录，DB 只存路径。
class MomentRecorderDrawer extends ConsumerStatefulWidget {
  const MomentRecorderDrawer({super.key});

  @override
  ConsumerState<MomentRecorderDrawer> createState() =>
      _MomentRecorderDrawerState();
}

class _MomentRecorderDrawerState extends ConsumerState<MomentRecorderDrawer> {
  final _contentController = TextEditingController();
  final List<XFile> _photos = [];
  String? _mood;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _pickMultiFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  bool get _canSave => _contentController.text.trim().isNotEmpty || _photos.isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) {
      _toast('写点什么，或加张照片吧');
      return;
    }
    try {
      await ref.read(momentProvider.notifier).addMoment(
            content: _contentController.text.trim().isEmpty
                ? null
                : _contentController.text.trim(),
            moodTag: _mood,
            photos: _photos,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast('保存失败: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildPhotoGrid(),
                  const SizedBox(height: 10),
                  _buildMoodSelector(),
                  const SizedBox(height: 10),
                  _buildContentField(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            _buildSaveBar(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _momentColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.camera_alt, size: 18, color: _momentColor),
        ),
        const SizedBox(width: 10),
        const Text('记录一个瞬间',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._photos.asMap().entries.map((entry) {
          final i = entry.key;
          return _PhotoThumb(
            file: File(entry.value.path),
            onTap: () => _removePhoto(i),
          );
        }),
        _AddPhotoButton(
          onCamera: _pickFromCamera,
          onGallery: _pickMultiFromGallery,
        ),
      ],
    );
  }

  Widget _buildMoodSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _moodOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (emoji, label) = _moodOptions[i];
          final selected = _mood == emoji;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _mood = selected ? null : emoji);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? _momentColor.withAlpha(230)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : const Color(0xFF616161),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 3,
        maxLength: 2000,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: '今天有什么值得记住的？',
          hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (_photos.isNotEmpty)
            Text('${_photos.length} 张照片',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          const Spacer(),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: _momentColor,
              disabledBackgroundColor: _momentColor.withAlpha(80),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('保存瞬间',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.file, required this.onTap});
  final File file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            file,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSourcePicker(context),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _momentColor.withAlpha(80),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 24, color: _momentColor),
            SizedBox(height: 4),
            Text('照片', style: TextStyle(fontSize: 11, color: _momentColor)),
          ],
        ),
      ),
    );
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(ctx);
                  onCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('从相册选择（可多选）'),
                onTap: () {
                  Navigator.pop(ctx);
                  onGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
