
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  static const _categories = [
    _Cat('food', '🍱', '三餐'),
    _Cat('transport', '🚗', '交通'),
    _Cat('entertainment', '🎉', '娱乐'),
    _Cat('drink', '💧', '饮品'),
    _Cat('shopping', '🛒', '购物'),
    _Cat('housing', '🏠', '住房'),
    _Cat('pet', '🐱', '宠物'),
    _Cat('other', '⚙️', '自定义'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isSelected = cat.id == selectedId;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onSelected(cat.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withAlpha(20)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cat {
  final String id;
  final String icon;
  final String name;
  const _Cat(this.id, this.icon, this.name);
}
