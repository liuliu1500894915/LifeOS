import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/pet_animation_state.dart';

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
    this.width = 120,
    this.height = 120,
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
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PetCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationState != widget.animationState) {
      _bounceController.repeat(reverse: true);
    }
  }

  double get _bodyWidth {
    final b = widget.bodyShapeLevel;
    if (b <= 20) return 68;
    if (b <= 50) return 80;
    if (b <= 80) return 88;
    return 96;
  }

  double get _bodyHeight {
    final b = widget.bodyShapeLevel;
    if (b <= 20) return 72;
    if (b <= 50) return 80;
    if (b <= 80) return 84;
    return 88;
  }

  double get _borderRadius {
    final b = widget.bodyShapeLevel;
    if (b <= 20) return 24;
    if (b <= 50) return 40;
    if (b <= 80) return 32;
    return 28;
  }

  Color _backgroundColor() {
    switch (widget.animationState) {
      case PetAnimationState.happy:
      case PetAnimationState.excited:
        return ModuleColors.statusExcellent.withAlpha(40);
      case PetAnimationState.tired:
        return ModuleColors.statusTired.withAlpha(40);
      case PetAnimationState.hungry:
      case PetAnimationState.thirsty:
        return ModuleColors.warning.withAlpha(40);
      case PetAnimationState.sick:
        return ModuleColors.statusCritical.withAlpha(40);
      case PetAnimationState.sleeping:
        return ModuleColors.analytics.withAlpha(30);
      case PetAnimationState.idle:
        return ModuleColors.home.withAlpha(30);
    }
  }

  IconData _icon() {
    switch (widget.animationState) {
      case PetAnimationState.happy:
        return Icons.sentiment_satisfied_alt;
      case PetAnimationState.excited:
        return Icons.celebration;
      case PetAnimationState.tired:
        return Icons.sentiment_dissatisfied;
      case PetAnimationState.hungry:
      case PetAnimationState.thirsty:
        return Icons.restaurant;
      case PetAnimationState.sick:
        return Icons.sick_outlined;
      case PetAnimationState.sleeping:
        return Icons.bedtime;
      case PetAnimationState.idle:
        return Icons.pets;
    }
  }

  String _defaultBubbleText() {
    if (widget.hydrationLevel < 40) return '想喝水!';
    if (widget.energyLevel < 40) return '好饿呀!';
    if (widget.moodLevel < 40) return '有点累了...';
    switch (widget.animationState) {
      case PetAnimationState.happy:
        return '今天感觉真棒!';
      case PetAnimationState.excited:
        return '太开心了!';
      case PetAnimationState.tired:
        return '有点累了...';
      case PetAnimationState.hungry:
        return '好饿呀!';
      case PetAnimationState.thirsty:
        return '想喝水!';
      case PetAnimationState.sick:
        return '身体不舒服...';
      case PetAnimationState.sleeping:
        return 'Zzz...';
      case PetAnimationState.idle:
        return '今天还要喝水!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleText = widget.bubbleText ?? _defaultBubbleText();
    final bg = _backgroundColor();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.showBubble)
            Positioned(
              top: -24,
              left: 10,
              right: 10,
              child: AnimatedOpacity(
                opacity: widget.animationState == PetAnimationState.sleeping ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(bubbleText,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                width: _bodyWidth,
                height: _bodyHeight,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: Center(
                  child: Icon(_icon(), size: 38, color: bg.withAlpha(200)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
