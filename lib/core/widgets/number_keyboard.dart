import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumberKeyboard extends StatelessWidget {
  const NumberKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.showDecimal = true,
    this.confirmIcon = Icons.check,
    this.onConfirm,
  });

  final void Function(String key) onKeyPressed;
  final VoidCallback? onBackspace;
  final bool showDecimal;
  final IconData confirmIcon;
  final VoidCallback? onConfirm;

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    onKeyPressed(key);
  }

  static const _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    final bottomRow = <String>[
      if (showDecimal) '.' else '',
      '0',
      '00',
    ];

    final hasActionRow = onBackspace != null || onConfirm != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _digitRows) _buildRow(row),
        _buildRow(bottomRow.where((k) => k.isNotEmpty).toList()),
        if (hasActionRow) _buildActionRow(context),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((key) => Expanded(child: _buildKey(key))).toList(),
    );
  }

  Widget _buildKey(String label) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onKey(label),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        if (onBackspace != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: SizedBox(
                height: 56,
                child: Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onBackspace,
                    child: const Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (onConfirm != null)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: SizedBox(
                height: 56,
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onConfirm,
                    child: Center(
                      child: Icon(
                        confirmIcon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
