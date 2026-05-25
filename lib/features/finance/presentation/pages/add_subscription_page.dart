import 'package:flutter/material.dart';

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _nextBillingDate = DateTime.now().add(const Duration(days: 30));
  String _billingCycle = 'MONTHLY';
  bool _alertEnabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('登记订阅服务'),
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
            _buildLabel('服务名称'),
            _buildTextField(_nameController, 'Netflix Premium'),
            const SizedBox(height: 16),
            _buildLabel('扣费金额'),
            _buildTextField(_amountController, '¥ 98.00', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildLabel('计费周期'),
            const SizedBox(height: 8),
            Row(
              children: ['MONTHLY', 'QUARTERLY', 'YEARLY'].map((cycle) {
                final selected = _billingCycle == cycle;
                final labels = {'MONTHLY': '每月付', 'QUARTERLY': '每季付', 'YEARLY': '每年付'};
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _billingCycle = cycle),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        labels[cycle]!,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected ? Colors.white : const Color(0xFF616161),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildLabel('下次扣款日期'),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _nextBillingDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _nextBillingDate = d);
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
                      '${_nextBillingDate.year}-${_nextBillingDate.month.toString().padLeft(2, '0')}-${_nextBillingDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('提前 3 天发出通知栏提醒', style: TextStyle(fontSize: 15)),
              value: _alertEnabled,
              onChanged: (v) => setState(() => _alertEnabled = v),
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
