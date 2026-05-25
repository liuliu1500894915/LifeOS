import 'package:flutter/material.dart';

class AddAssetPage extends StatefulWidget {
  const AddAssetPage({super.key});

  @override
  State<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends State<AddAssetPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  String _selectedIcon = 'laptop';
  bool _projectToRoom = true;

  static const _iconOptions = [
    ('laptop', '💻'),
    ('chair', '🪑'),
    ('camera', '📷'),
    ('guitar', '🎸'),
    ('tablet', '📱'),
    ('car', '🚗'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('新增资产'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('资产名称'),
            _buildTextField(_nameController, 'MacBook Pro M3 Max'),
            const SizedBox(height: 16),
            _buildLabel('购入价格'),
            _buildTextField(_priceController, '¥ 18,000', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildLabel('购入日期'),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate,
                  firstDate: DateTime(2010),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _purchaseDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF757575)),
                    const SizedBox(width: 8),
                    Text(
                      '${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('选择图标'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _iconOptions.map((opt) {
                final selected = _selectedIcon == opt.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = opt.$1),
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primary.withAlpha(20) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(child: Text(opt.$2, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('在虚拟房间中展示', style: TextStyle(fontSize: 15)),
              value: _projectToRoom,
              onChanged: (v) => setState(() => _projectToRoom = v),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF616161))),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}
