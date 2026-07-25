import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 「奶油玻璃」视觉系统 —— 玻璃（空气感）与软陶（手感）按**层级**分工。
///
/// 一条原则：**越重要越实体，越是氛围越透明**。两种材质从不在同一层级平级
/// 出现，因此眼睛读到的是「远近关系」而不是「材质混乱」：
///
/// | 层 | 材质 | 用在哪 |
/// |---|---|---|
/// | L1 氛围 | 玻璃 [GlassPanel] | 页面光晕底、导航栏、状态 chip、弹层 |
/// | L2 内容 | 奶油实体 [CreamCard] | 数据卡、列表、表单（要阅读，故不透明） |
/// | L3 主角 | 完整软陶 [ClaySurface] | 核心数字卡、主行动按钮、宠物房间 |
class CreamGlass {
  CreamGlass._();

  // ── 色板 ──
  /// 页面底色（奶油微绿灰）。
  static const Color ground = Color(0xFFEFF4EF);

  /// 内容卡片底色（比 ground 更亮的奶油白）。
  static const Color surface = Color(0xFFFCFEFB);

  /// 主色（软陶绿）与其深色端，用于 L3 渐变。
  static const Color brand = Color(0xFF45A87C);
  static const Color brandLight = Color(0xFF6FC79E);

  /// 行动色（蜜桃），也用于支出/负向数字。
  static const Color peach = Color(0xFFF0785A);
  static const Color peachLight = Color(0xFFFFAB80);

  // 文字阶梯
  static const Color ink = Color(0xFF2C3A33);
  static const Color inkMid = Color(0xFF7A8C82);
  static const Color inkSoft = Color(0xFF94A69B);

  /// 背景光晕的三个色斑（L1 氛围层）。
  static const Color auroraMint = Color(0xFFA8E6C4);
  static const Color auroraPeach = Color(0xFFFFD4B8);
  static const Color auroraSky = Color(0xFFBFE3F5);

  // ── 形制 ──
  static const double rHero = 24;
  static const double rCard = 20;
  static const double rSmall = 16;

  /// L2 内容层阴影：柔和外阴影 + 内高光（软陶感，但比 L3 薄）。
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x1C486858), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// L3 主角层阴影：厚重外阴影（内高光由渐变 + 内描边模拟）。
  static List<BoxShadow> clayShadow(Color tint) => [
        BoxShadow(
          color: tint.withAlpha(78),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}

/// L1 · 氛围层：页面背景的柔和光晕。
///
/// 放在页面最底层（`Stack` 的第一个孩子），上面的玻璃元素会透出这些色斑，
/// 从而与实体卡片拉开「远近」。
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: CreamGlass.ground),
        child: SizedBox.expand(child: _AuroraBlobs()),
      ),
    );
  }
}

class _AuroraBlobs extends StatelessWidget {
  const _AuroraBlobs();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AuroraPainter());
  }
}

class _AuroraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            color.withAlpha(225),
            color.withAlpha(0),
          ], [0.0, 1.0])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }

    blob(Offset(size.width * 0.16, size.height * 0.08), size.width * 0.52,
        CreamGlass.auroraMint);
    blob(Offset(size.width * 0.92, size.height * 0.18), size.width * 0.46,
        CreamGlass.auroraPeach);
    blob(Offset(size.width * 0.60, size.height * 0.72), size.width * 0.58,
        CreamGlass.auroraSky);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// L1 · 氛围层：毛玻璃面板（导航栏、chip、弹层）。
///
/// 只用在**不承载长文阅读**的地方 —— 透明会干扰可读性。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = CreamGlass.rSmall,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.blur = 14,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(140),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withAlpha(204)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// L2 · 内容层：奶油实体卡（数据卡、列表、表单）。
///
/// 不透明 —— 这里要被长时间阅读。阴影比 L3 薄，视觉重量低一档。
class CreamCard extends StatelessWidget {
  const CreamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = CreamGlass.rCard,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CreamGlass.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: CreamGlass.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// L3 · 主角层：完整软陶（核心数字卡、主行动按钮）。
///
/// 饱和渐变 + 厚外阴影 + 内高光/内暗边 —— 视觉重量最大，每屏只用一两个。
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.from = CreamGlass.brandLight,
    this.to = CreamGlass.brand,
    this.radius = CreamGlass.rHero,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color from;
  final Color to;
  final double radius;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: CreamGlass.clayShadow(to),
      ),
      // 内高光（顶部）与内暗边（底部）模拟黏土的厚度。
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withAlpha(46),
            Colors.white.withAlpha(0),
            Colors.black.withAlpha(20),
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      ),
    );
  }
}

/// 区块小标题（「账户与资产」这类）。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: CreamGlass.inkMid,
        ),
      ),
    );
  }
}
