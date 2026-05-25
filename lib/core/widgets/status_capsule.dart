import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact status badge used for pet health, budget alerts,
/// subscription warnings, and relationship warmth.
class StatusCapsule extends StatelessWidget {
  const StatusCapsule({
    super.key,
    required this.label,
    this.color,
    this.onTap,
    this.icon,
    this.size = StatusCapsuleSize.medium,
  });

  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;
  final StatusCapsuleSize size;

  Color _defaultColor() {
    switch (label) {
      case '极佳':
      case 'EXCELLENT':
        return ModuleColors.statusExcellent;
      case '良好':
      case 'GOOD':
        return ModuleColors.statusExcellent;
      case '正常':
      case 'NORMAL':
        return ModuleColors.statusNormal;
      case '偏低':
      case 'LOW':
        return ModuleColors.statusTired;
      case '警告':
      case 'WARNING':
        return ModuleColors.warning;
      case '危险':
      case 'CRITICAL':
        return ModuleColors.statusCritical;
      default:
        return ModuleColors.statusNormal;
    }
  }

  double _height() {
    switch (size) {
      case StatusCapsuleSize.small:
        return 24;
      case StatusCapsuleSize.medium:
        return 30;
      case StatusCapsuleSize.large:
        return 36;
    }
  }

  double _fontSize() {
    switch (size) {
      case StatusCapsuleSize.small:
        return 11;
      case StatusCapsuleSize.medium:
        return 12;
      case StatusCapsuleSize.large:
        return 14;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? _defaultColor();

    final capsule = Container(
      height: _height(),
      padding: EdgeInsets.symmetric(
        horizontal: size == StatusCapsuleSize.small ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(30),
        borderRadius: BorderRadius.circular(_height() / 2),
        border: Border.all(
          color: effectiveColor.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _fontSize() + 2, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _fontSize(),
              fontWeight: FontWeight.w600,
              color: effectiveColor,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: capsule,
      );
    }
    return capsule;
  }
}

enum StatusCapsuleSize { small, medium, large }
