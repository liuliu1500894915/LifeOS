import 'package:flutter/material.dart';

/// Reusable bottom sheet wrapper with consistent styling.
/// Supports drag handle, optional title bar with cancel/confirm buttons,
/// and scrollable content.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    this.title,
    this.onCancel,
    this.onConfirm,
    this.confirmLabel = '确定',
    required this.child,
    this.showDragHandle = true,
    this.isScrollControlled = true,
  });

  final String? title;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final Widget child;
  final bool showDragHandle;
  final bool isScrollControlled;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null || onCancel != null || onConfirm != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('取消'),
                      )
                    else
                      const SizedBox(width: 60),
                    if (title != null)
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (onConfirm != null)
                      TextButton(
                        onPressed: onConfirm,
                        child: Text(confirmLabel),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Convenience function to show a bottom sheet with AppBottomSheet styling.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor ?? Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
