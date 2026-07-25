import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/pet_animation_state.dart';

/// 宠物角色：矢量绘制的「团子」造型 + 多重循环动画。
///
/// 此前这里是「圆角方块 + 一个 Material 图标」，缺少养成游戏该有的生命感。
/// 现改为 [CustomPainter] 绘制的角色，并叠加：
/// - **呼吸**：身体轻微起伏（所有状态）
/// - **眨眼**：随机间隔的自然眨眼
/// - **尾巴摆动**：心情越好摆得越欢
/// - **跳跃**：happy / excited 时上下弹跳
/// - **状态表情**：困倦半闭眼、生病 ×_×、睡觉闭眼 + Zzz、饥渴小圆嘴
///
/// 体型（[bodyShapeLevel]）沿用原有分档：吃得多会变圆。
class PetCharacter extends StatefulWidget {
  const PetCharacter({
    super.key,
    this.animationState = PetAnimationState.idle,
    this.energyLevel = 100,
    this.moodLevel = 100,
    this.hydrationLevel = 100,
    this.bodyShapeLevel = 0,
    this.showBubble = true,
    this.bubbleText,
    this.width = 150,
    this.height = 150,
  });

  final PetAnimationState animationState;
  final int energyLevel;
  final int moodLevel;
  final int hydrationLevel;
  final int bodyShapeLevel;
  final bool showBubble;
  final String? bubbleText;
  final double width;
  final double height;

  @override
  State<PetCharacter> createState() => _PetCharacterState();
}

class _PetCharacterState extends State<PetCharacter>
    with SingleTickerProviderStateMixin {
  /// 单个循环控制器驱动全部动画（呼吸 / 跳跃 / 尾巴 / 眨眼 / Zzz）。
  ///
  /// 眨眼刻意也走这个 ticker 的相位而非 `Future.delayed` —— 后者会在
  /// widget 树销毁后留下 pending timer，导致 widget 测试失败。
  late final AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  /// 体型分档（沿用原有阈值）。
  double get _girth {
    final b = widget.bodyShapeLevel;
    if (b <= 20) return 0.88;
    if (b <= 50) return 1.0;
    if (b <= 80) return 1.10;
    return 1.20;
  }

  String? get _bubbleText {
    if (!widget.showBubble) return null;
    if (widget.bubbleText != null) return widget.bubbleText;
    if (widget.animationState == PetAnimationState.sleeping) return null;
    if (widget.hydrationLevel < 40) return '想喝水…';
    if (widget.energyLevel < 40) return '好饿呀！';
    if (widget.moodLevel < 40) return '有点累了…';
    switch (widget.animationState) {
      case PetAnimationState.happy:
        return '今天感觉真棒！';
      case PetAnimationState.excited:
        return '太开心了！';
      case PetAnimationState.tired:
        return '有点累了…';
      case PetAnimationState.hungry:
        return '好饿呀！';
      case PetAnimationState.thirsty:
        return '想喝水…';
      case PetAnimationState.sick:
        return '身体不舒服…';
      case PetAnimationState.sleeping:
      case PetAnimationState.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubble = _bubbleText;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _PetPainter(
                  state: widget.animationState,
                  t: _idleController.value,
                  girth: _girth,
                ),
              );
            },
          ),
          if (bubble != null)
            Positioned(
              top: -18,
              child: _SpeechBubble(text: bubble),
            ),
        ],
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  _PetPainter({
    required this.state,
    required this.t,
    required this.girth,
  });

  /// 当前状态。
  final PetAnimationState state;

  /// 循环动画进度 0~1。
  final double t;

  /// 体型系数。
  final double girth;

  /// 眨眼进度 0（睁）~1（闭）：在循环末段快速开合一次。
  double get blink {
    const start = 0.86;
    const end = 0.93;
    if (t < start || t > end) return 0;
    return math.sin((t - start) / (end - start) * math.pi);
  }

  bool get _isSleeping => state == PetAnimationState.sleeping;
  bool get _isLively =>
      state == PetAnimationState.happy || state == PetAnimationState.excited;

  /// 主体毛色随状态变化。
  Color get _furColor {
    switch (state) {
      case PetAnimationState.sick:
        return const Color(0xFFAFC0B4);
      case PetAnimationState.sleeping:
        return const Color(0xFFDCC5A8);
      case PetAnimationState.tired:
        return const Color(0xFFE7BE95);
      default:
        return const Color(0xFFF3AE68);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 呼吸：正弦起伏；跳跃：活泼状态额外上下位移。
    final breathe = math.sin(t * math.pi * 2) * 0.018;
    final hop = _isLively ? -math.sin(t * math.pi * 4).abs() * h * 0.055 : 0.0;
    final bodyW = w * 0.60 * girth;
    final bodyH = h * 0.54 * (1 + breathe) * (girth * 0.95);
    final cy = h * 0.58 + hop;

    _paintShadow(canvas, cx, h, bodyW, hop);
    _paintTail(canvas, cx, cy, bodyW, bodyH);
    _paintBody(canvas, cx, cy, bodyW, bodyH);
    _paintEars(canvas, cx, cy, bodyW, bodyH);
    _paintFace(canvas, cx, cy, bodyW, bodyH);
    _paintPaws(canvas, cx, cy, bodyW, bodyH);
    if (_isSleeping) _paintZzz(canvas, cx, cy, bodyW, bodyH);
    if (state == PetAnimationState.sick) {
      _paintSickMark(canvas, cx, cy, bodyW, bodyH);
    }
  }

  /// 脚下阴影：跳起时变小变淡。
  void _paintShadow(Canvas canvas, double cx, double h, double bodyW, double hop) {
    final lift = (hop.abs() / (h * 0.055)).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.90),
        width: bodyW * (0.88 - lift * 0.16),
        height: h * 0.05 * (1 - lift * 0.25),
      ),
      Paint()..color = Colors.black.withAlpha((36 * (1 - lift * 0.4)).round()),
    );
  }

  /// 尾巴：心情越好摆得越快越大。
  void _paintTail(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    final speed = _isLively ? 6.0 : (_isSleeping ? 1.0 : 3.0);
    final amp = _isLively ? 0.9 : (_isSleeping ? 0.15 : 0.45);
    final swing = math.sin(t * math.pi * speed) * amp;
    final root = Offset(cx + bodyW * 0.38, cy + bodyH * 0.16);
    final tip = Offset(
      root.dx + bodyW * (0.30 + swing * 0.10),
      root.dy - bodyH * (0.28 + swing * 0.22),
    );
    final path = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(
        root.dx + bodyW * 0.34,
        root.dy + bodyH * (0.02 - swing * 0.10),
        tip.dx,
        tip.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _furColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyW * 0.15
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 身体：团子造型（头身一体）。
  void _paintBody(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    final rect =
        Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(bodyW * 0.46)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(_furColor, Colors.white, 0.20)!,
            _furColor,
          ],
        ).createShader(rect),
    );
    // 肚皮
    final belly = Rect.fromCenter(
      center: Offset(cx, cy + bodyH * 0.17),
      width: bodyW * 0.54,
      height: bodyH * 0.44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(belly, Radius.circular(bodyW * 0.28)),
      Paint()..color = const Color(0xFFFFF6E9).withAlpha(228),
    );
  }

  /// 耳朵（睡觉时微垂）。
  void _paintEars(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    final fur = Paint()..color = _furColor;
    final inner = Paint()..color = const Color(0xFFFFC6BB);
    for (final side in [-1, 1]) {
      final base = Offset(cx + side * bodyW * 0.28, cy - bodyH * 0.34);
      final droop = _isSleeping ? bodyH * 0.07 : 0.0;
      final tip =
          Offset(base.dx + side * bodyW * 0.15, base.dy - bodyH * 0.26 + droop);
      final ear = Path()
        ..moveTo(base.dx - side * bodyW * 0.10, base.dy)
        ..quadraticBezierTo(
            base.dx + side * bodyW * 0.02, tip.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(base.dx + side * bodyW * 0.17,
            base.dy - bodyH * 0.04, base.dx + side * bodyW * 0.12,
            base.dy + bodyH * 0.02)
        ..close();
      canvas.drawPath(ear, fur);
      final innerEar = Path()
        ..moveTo(base.dx - side * bodyW * 0.02, base.dy - bodyH * 0.01)
        ..quadraticBezierTo(base.dx + side * bodyW * 0.05,
            tip.dy + bodyH * 0.07, tip.dx - side * bodyW * 0.03,
            tip.dy + bodyH * 0.06)
        ..quadraticBezierTo(base.dx + side * bodyW * 0.10,
            base.dy - bodyH * 0.03, base.dx + side * bodyW * 0.06, base.dy)
        ..close();
      canvas.drawPath(innerEar, inner);
    }
  }

  /// 脸：眼睛 / 腮红 / 鼻子 / 嘴。
  void _paintFace(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    final eyeY = cy - bodyH * 0.09;
    final eyeDx = bodyW * 0.17;

    // 闭眼程度：眨眼 + 状态叠加
    var closed = blink;
    if (_isSleeping) closed = 1.0;
    if (state == PetAnimationState.tired) closed = math.max(closed, 0.60);

    for (final side in [-1, 1]) {
      final ec = Offset(cx + side * eyeDx, eyeY);
      if (state == PetAnimationState.sick) {
        // ×_× 眼
        final r = bodyW * 0.052;
        final p = Paint()
          ..color = const Color(0xFF3E3226)
          ..strokeWidth = bodyW * 0.026
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(ec.translate(-r, -r), ec.translate(r, r), p);
        canvas.drawLine(ec.translate(r, -r), ec.translate(-r, r), p);
      } else if (_isLively) {
        // ^ ^ 笑眼
        final p = Paint()
          ..color = const Color(0xFF3E3226)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bodyW * 0.030
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(ec.dx - bodyW * 0.055, ec.dy + bodyW * 0.022)
            ..quadraticBezierTo(ec.dx, ec.dy - bodyW * 0.048,
                ec.dx + bodyW * 0.055, ec.dy + bodyW * 0.022),
          p,
        );
      } else if (closed > 0.55) {
        // 闭眼横线
        canvas.drawLine(
          ec.translate(-bodyW * 0.052, 0),
          ec.translate(bodyW * 0.052, 0),
          Paint()
            ..color = const Color(0xFF3E3226)
            ..strokeWidth = bodyW * 0.028
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // 睁眼：黑瞳 + 高光
        final rx = bodyW * 0.060;
        final ry = rx * (1 - closed * 0.85);
        canvas.drawOval(
          Rect.fromCenter(center: ec, width: rx * 2, height: ry * 2),
          Paint()..color = const Color(0xFF3E3226),
        );
        if (closed < 0.25) {
          canvas.drawCircle(
            ec.translate(rx * 0.34, -ry * 0.36),
            rx * 0.30,
            Paint()..color = Colors.white.withAlpha(230),
          );
        }
      }
    }

    // 腮红
    final blushAlpha = _isLively ? 120 : 72;
    for (final side in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * bodyW * 0.29, eyeY + bodyH * 0.10),
          width: bodyW * 0.15,
          height: bodyH * 0.07,
        ),
        Paint()..color = const Color(0xFFFF8A8A).withAlpha(blushAlpha),
      );
    }

    // 鼻子
    final noseC = Offset(cx, eyeY + bodyH * 0.10);
    canvas.drawPath(
      Path()
        ..moveTo(noseC.dx - bodyW * 0.042, noseC.dy - bodyH * 0.012)
        ..lineTo(noseC.dx + bodyW * 0.042, noseC.dy - bodyH * 0.012)
        ..lineTo(noseC.dx, noseC.dy + bodyH * 0.032)
        ..close(),
      Paint()..color = const Color(0xFF5C4436),
    );

    // 嘴
    final mouth = Paint()
      ..color = const Color(0xFF5C4436)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bodyW * 0.024
      ..strokeCap = StrokeCap.round;
    final my = noseC.dy + bodyH * 0.05;
    if (_isLively) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, my), width: bodyW * 0.20, height: bodyH * 0.13),
        0.15,
        math.pi - 0.3,
        false,
        mouth,
      );
    } else if (state == PetAnimationState.hungry ||
        state == PetAnimationState.thirsty) {
      canvas.drawCircle(Offset(cx, my + bodyH * 0.02), bodyW * 0.033, mouth);
    } else if (_isSleeping) {
      canvas.drawLine(Offset(cx - bodyW * 0.032, my + bodyH * 0.02),
          Offset(cx + bodyW * 0.032, my + bodyH * 0.02), mouth);
    } else {
      // 常态 ω 形
      for (final side in [-1, 1]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx + side * bodyW * 0.042, my + bodyH * 0.010),
            width: bodyW * 0.085,
            height: bodyH * 0.065,
          ),
          0,
          math.pi,
          false,
          mouth,
        );
      }
    }
  }

  /// 前爪。
  void _paintPaws(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    final paint = Paint()..color = Color.lerp(_furColor, Colors.white, 0.12)!;
    final y = cy + bodyH * 0.40;
    for (final side in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * bodyW * 0.23, y),
          width: bodyW * 0.23,
          height: bodyH * 0.15,
        ),
        paint,
      );
    }
  }

  /// 睡觉的 Zzz（上浮淡出）。
  void _paintZzz(Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    for (var i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final op = (1 - phase).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: bodyW * (0.16 + i * 0.05),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7E8CA8).withAlpha((op * 200).round()),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(cx + bodyW * (0.32 + phase * 0.22),
            cy - bodyH * (0.40 + phase * 0.50)),
      );
    }
  }

  /// 生病：头顶冒汗珠。
  void _paintSickMark(
      Canvas canvas, double cx, double cy, double bodyW, double bodyH) {
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.33, cy - bodyH * 0.42)
        ..quadraticBezierTo(cx + bodyW * 0.43, cy - bodyH * 0.30,
            cx + bodyW * 0.33, cy - bodyH * 0.26)
        ..quadraticBezierTo(cx + bodyW * 0.23, cy - bodyH * 0.30,
            cx + bodyW * 0.33, cy - bodyH * 0.42)
        ..close(),
      Paint()..color = const Color(0xFF7EC8F0).withAlpha(220),
    );
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) =>
      old.t != t || old.state != state || old.girth != girth;
}

/// 宠物头顶的对话气泡。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(242),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF5D4B3A),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
