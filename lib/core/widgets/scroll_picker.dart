import 'package:flutter/material.dart';

class ScrollPicker extends StatefulWidget {
  const ScrollPicker({
    super.key,
    required this.items,
    required this.onChanged,
    this.selectedIndex = 0,
    this.itemHeight = 44,
    this.visibleItems = 5,
    this.foregroundColor,
    this.unselectedColor,
  });

  final List<String> items;
  final ValueChanged<int> onChanged;
  final int selectedIndex;
  final double itemHeight;
  final int visibleItems;
  final Color? foregroundColor;
  final Color? unselectedColor;

  @override
  State<ScrollPicker> createState() => _ScrollPickerState();
}

class _ScrollPickerState extends State<ScrollPicker> {
  late final FixedExtentScrollController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _controller = FixedExtentScrollController(initialItem: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fgColor =
        widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final dimColor = widget.unselectedColor ?? Colors.grey.shade400;

    return SizedBox(
      height: widget.itemHeight * widget.visibleItems,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: widget.itemHeight,
        diameterRatio: 1.8,
        perspective: 0.004,
        onSelectedItemChanged: (i) {
          setState(() => _currentIndex = i);
          widget.onChanged(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.items.length,
          builder: (context, index) {
            final isSelected = _currentIndex == index;
            return Center(
              child: Text(
                widget.items[index],
                style: TextStyle(
                  fontSize: isSelected ? 20 : 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? fgColor : dimColor,
                  height: 1.4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
