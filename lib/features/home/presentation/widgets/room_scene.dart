import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 宠物房间的场景背景：墙面 / 窗户 / 木地板 / 地毯 + 内置家具（床、书桌、
/// 书架、绿植、壁灯）。
///
/// 全部用 [CustomPainter] 矢量绘制，不依赖任何图片资源 —— 任意尺寸下都清晰，
/// 且可随昼夜（[isNight]）与宠物心情（[moodTint]）改变光照氛围。
///
/// 用户的固定资产摆件与宠物角色由调用方叠在本背景之上（见 `home_page`）。
class RoomScene extends StatelessWidget {
  const RoomScene({
    super.key,
    required this.isNight,
    this.moodTint,
  });

  /// 夜间模式：暖光台灯亮起、窗外是星空。
  final bool isNight;

  /// 心情色调（宠物状态不佳时给房间一层淡淡的颜色）。
  final Color? moodTint;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomPainter(isNight: isNight, moodTint: moodTint),
      size: Size.infinite,
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.isNight, this.moodTint});

  final bool isNight;
  final Color? moodTint;

  // ── 布局常量（归一化，随房间尺寸缩放）──
  static const _floorTop = 0.60; // 墙与地板的分界

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorY = h * _floorTop;

    _paintWall(canvas, w, h, floorY);
    _paintWindow(canvas, w, h);
    _paintWallArt(canvas, w, h);
    _paintShelf(canvas, w, h, floorY);
    _paintFloor(canvas, w, h, floorY);
    _paintRug(canvas, w, h);
    _paintBed(canvas, w, h, floorY);
    _paintDesk(canvas, w, h, floorY);
    _paintPlant(canvas, w, h, floorY);
    if (isNight) _paintLampGlow(canvas, w, h);
    if (moodTint != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = moodTint!.withAlpha(18),
      );
    }
  }

  // ── 墙面 ──
  void _paintWall(Canvas canvas, double w, double h, double floorY) {
    final wallRect = Rect.fromLTWH(0, 0, w, floorY);
    final top = isNight ? const Color(0xFF3B3A5A) : const Color(0xFFFFF3E4);
    final bottom = isNight ? const Color(0xFF4A4668) : const Color(0xFFFBE3CC);
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(wallRect),
    );
    // 踢脚线
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - h * 0.022, w, h * 0.022),
      Paint()..color = isNight ? const Color(0xFF34324E) : const Color(0xFFE8C7A6),
    );
  }

  // ── 窗户（白天蓝天 / 夜晚星空）──
  void _paintWindow(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(w * 0.07, h * 0.10, w * 0.26, h * 0.30);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    // 窗框
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(10)),
      Paint()..color = isNight ? const Color(0xFF2B2942) : const Color(0xFFB98A62),
    );
    // 窗景
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? [const Color(0xFF1B2452), const Color(0xFF33407A)]
              : [const Color(0xFF9BD7F5), const Color(0xFFD8F0FB)],
        ).createShader(rect),
    );
    if (isNight) {
      // 月亮 + 星星
      canvas.drawCircle(
        Offset(rect.left + rect.width * 0.68, rect.top + rect.height * 0.28),
        rect.width * 0.11,
        Paint()..color = const Color(0xFFFFF6D5),
      );
      final star = Paint()..color = Colors.white.withAlpha(210);
      const pts = [
        [0.22, 0.20], [0.40, 0.44], [0.18, 0.62], [0.55, 0.72], [0.78, 0.58],
      ];
      for (final p in pts) {
        canvas.drawCircle(
          Offset(rect.left + rect.width * p[0], rect.top + rect.height * p[1]),
          1.6,
          star,
        );
      }
    } else {
      // 云
      final cloud = Paint()..color = Colors.white.withAlpha(220);
      void puff(double cx, double cy, double r) => canvas.drawCircle(
          Offset(rect.left + rect.width * cx, rect.top + rect.height * cy),
          rect.width * r,
          cloud);
      puff(0.30, 0.32, 0.10);
      puff(0.42, 0.30, 0.13);
      puff(0.55, 0.34, 0.09);
      puff(0.70, 0.62, 0.08);
      puff(0.80, 0.60, 0.10);
    }
    // 窗棂
    final bar = Paint()
      ..color = isNight ? const Color(0xFF2B2942) : const Color(0xFFB98A62)
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), bar);
    canvas.drawLine(
        Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), bar);
  }

  // ── 墙上挂画 ──
  void _paintWallArt(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(w * 0.63, h * 0.12, w * 0.15, h * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(4)),
      Paint()..color = isNight ? const Color(0xFF2B2942) : const Color(0xFFC49A6C),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isNight
              ? [const Color(0xFF44507F), const Color(0xFF5B6BA0)]
              : [const Color(0xFFFFD9A0), const Color(0xFFFFB3C1)],
        ).createShader(rect),
    );
    // 画里的小山 + 太阳
    final hill = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.38, rect.top + rect.height * 0.45)
      ..lineTo(rect.left + rect.width * 0.72, rect.bottom)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF7EC8A0).withAlpha(220));
    canvas.drawCircle(
      Offset(rect.left + rect.width * 0.74, rect.top + rect.height * 0.28),
      rect.width * 0.10,
      Paint()..color = const Color(0xFFFFF1B8),
    );
  }

  // ── 墙上层板（书架）──
  void _paintShelf(Canvas canvas, double w, double h, double floorY) {
    final y = h * 0.36;
    final rect = Rect.fromLTWH(w * 0.60, y, w * 0.24, h * 0.018);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = isNight ? const Color(0xFF6B5A47) : const Color(0xFFC08A5A),
    );
    // 书（不同高度的小方块）
    const books = [
      [0.02, 0.055, Color(0xFFE57373)],
      [0.08, 0.070, Color(0xFF64B5F6)],
      [0.14, 0.048, Color(0xFF81C784)],
      [0.19, 0.062, Color(0xFFFFB74D)],
    ];
    for (final b in books) {
      final bw = w * 0.045;
      final bh = h * (b[1] as double);
      canvas.drawRect(
        Rect.fromLTWH(rect.left + w * (b[0] as double), rect.top - bh, bw, bh),
        Paint()..color = (b[2] as Color).withAlpha(isNight ? 180 : 255),
      );
    }
  }

  // ── 木地板 ──
  void _paintFloor(Canvas canvas, double w, double h, double floorY) {
    final rect = Rect.fromLTWH(0, floorY, w, h - floorY);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? [const Color(0xFF5A4636), const Color(0xFF6E5744)]
              : [const Color(0xFFD9A876), const Color(0xFFC28E5C)],
        ).createShader(rect),
    );
    // 透视地板缝：从消失点向下发散
    final seam = Paint()
      ..color = Colors.black.withAlpha(isNight ? 40 : 28)
      ..strokeWidth = 1.4;
    final vanish = Offset(w * 0.5, floorY - h * 0.22);
    for (var i = -3; i <= 4; i++) {
      final bx = w * 0.5 + i * w * 0.19;
      canvas.drawLine(Offset(bx, h), vanish, seam);
    }
    // 横向木板线
    for (var i = 1; i <= 3; i++) {
      final y = floorY + (h - floorY) * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), seam);
    }
  }

  // ── 地毯 ──
  void _paintRug(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.5, h * 0.855);
    final rect = Rect.fromCenter(center: center, width: w * 0.52, height: h * 0.17);
    canvas.drawOval(
      rect,
      Paint()..color = (isNight ? const Color(0xFF7E6BA8) : const Color(0xFFF3A5A5))
          .withAlpha(isNight ? 150 : 190),
    );
    canvas.drawOval(
      rect.deflate(math.min(w, h) * 0.018),
      Paint()..color = (isNight ? const Color(0xFF9A87C4) : const Color(0xFFFFC9C9))
          .withAlpha(isNight ? 150 : 200),
    );
  }

  // ── 床（左下）──
  void _paintBed(Canvas canvas, double w, double h, double floorY) {
    final base = Rect.fromLTWH(w * 0.015, floorY - h * 0.055, w * 0.30, h * 0.20);
    // 床体
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(10)),
      Paint()..color = isNight ? const Color(0xFF6D5B49) : const Color(0xFFB07E56),
    );
    // 床垫 / 被子
    final quilt = Rect.fromLTWH(
        base.left + base.width * 0.06, base.top + base.height * 0.10,
        base.width * 0.88, base.height * 0.58);
    canvas.drawRRect(
      RRect.fromRectAndRadius(quilt, const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isNight
              ? [const Color(0xFF7C8BC7), const Color(0xFF6675B4)]
              : [const Color(0xFFAFD8F0), const Color(0xFF89BFE3)],
        ).createShader(quilt),
    );
    // 枕头
    final pillow = Rect.fromLTWH(
        base.left + base.width * 0.10, base.top + base.height * 0.02,
        base.width * 0.30, base.height * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillow, const Radius.circular(6)),
      Paint()..color = isNight ? const Color(0xFFD8D4E8) : Colors.white,
    );
  }

  // ── 书桌 + 台灯（右下）──
  void _paintDesk(Canvas canvas, double w, double h, double floorY) {
    final topRect = Rect.fromLTWH(w * 0.63, floorY + h * 0.015, w * 0.33, h * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, const Radius.circular(6)),
      Paint()..color = isNight ? const Color(0xFF7A6650) : const Color(0xFFCE9C68),
    );
    // 桌腿
    final legPaint = Paint()
      ..color = isNight ? const Color(0xFF63523F) : const Color(0xFFB07E56);
    final legH = h * 0.11;
    canvas.drawRect(
        Rect.fromLTWH(topRect.left + w * 0.02, topRect.bottom, w * 0.022, legH),
        legPaint);
    canvas.drawRect(
        Rect.fromLTWH(topRect.right - w * 0.042, topRect.bottom, w * 0.022, legH),
        legPaint);
    // 台灯
    final lampBase = Offset(topRect.left + topRect.width * 0.22, topRect.top);
    canvas.drawRect(
      Rect.fromCenter(center: lampBase.translate(0, -h * 0.035),
          width: w * 0.008, height: h * 0.07),
      Paint()..color = const Color(0xFF8D8D8D),
    );
    final shade = Path()
      ..moveTo(lampBase.dx - w * 0.045, lampBase.dy - h * 0.068)
      ..lineTo(lampBase.dx + w * 0.045, lampBase.dy - h * 0.068)
      ..lineTo(lampBase.dx + w * 0.028, lampBase.dy - h * 0.105)
      ..lineTo(lampBase.dx - w * 0.028, lampBase.dy - h * 0.105)
      ..close();
    canvas.drawPath(
        shade,
        Paint()
          ..color = isNight ? const Color(0xFFFFD98A) : const Color(0xFFE0A46A));
  }

  // ── 桌面盆栽 ──
  //
  // 刻意摆在书桌右端而非地板中央：地板中央是地毯与宠物的位置，放在那里会被
  // 宠物完全遮住。
  void _paintPlant(Canvas canvas, double w, double h, double floorY) {
    final potBottom = floorY + h * 0.016; // 坐在桌面上
    final cx = w * 0.90;
    final potW = w * 0.026;
    final potH = h * 0.042;
    final pot = Path()
      ..moveTo(cx - potW, potBottom - potH)
      ..lineTo(cx + potW, potBottom - potH)
      ..lineTo(cx + potW * 0.74, potBottom)
      ..lineTo(cx - potW * 0.74, potBottom)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFFCF7B52));
    // 叶子
    final leaf = Paint()
      ..color = (isNight ? const Color(0xFF3E8C63) : const Color(0xFF4CAF7D));
    final base = potBottom - potH;
    for (var i = -1; i <= 1; i++) {
      final tip = Offset(
        cx + i * w * 0.030,
        base - h * (0.062 - i.abs() * 0.016),
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx, base)
          ..quadraticBezierTo(
              cx + i * w * 0.038, tip.dy + h * 0.016, tip.dx, tip.dy)
          ..quadraticBezierTo(
              cx + i * w * 0.010, tip.dy + h * 0.026, cx, base),
        leaf,
      );
    }
  }

  // ── 夜间台灯光晕 ──
  void _paintLampGlow(Canvas canvas, double w, double h) {
    final c = Offset(w * 0.70, h * 0.56);
    canvas.drawCircle(
      c,
      w * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE0A3).withAlpha(90),
            const Color(0xFFFFE0A3).withAlpha(0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.22)),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.isNight != isNight || old.moodTint != moodTint;
}
