import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/calculators/adc_calculator.dart';
import '../providers/finance_providers.dart';

class AssetListPage extends ConsumerWidget {
  const AssetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetListProvider);
    final totalValue = assets.fold<double>(0, (s, a) => s + a.purchasePrice);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('固定资产库'),
        backgroundColor: const Color(0xFFF8F9FA),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('资产折旧', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(totalValue, assets.length),
          Expanded(
            child: assets.isEmpty
                ? const Center(child: Text('暂无资产，点击 + 添加', style: TextStyle(fontSize: 15, color: Color(0xFF9E9E9E))))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: assets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AssetCard(asset: assets[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addAsset),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryBar(double total, int count) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('资产总估值', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
          const Spacer(),
          Text('¥${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ModuleColors.finance)),
          const SizedBox(width: 8),
          Text('$count 件', style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});
  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final adc = AdcCalculator.calculate(purchasePrice: asset.purchasePrice, purchaseDate: asset.purchaseDate, today: now);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.addAsset, extra: asset),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_assetIcon(asset.iconId), style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('购入: ¥${asset.purchasePrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                      const SizedBox(width: 12),
                      Text('持有: ${now.difference(asset.purchaseDate).inDays}天',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_down, size: 14, color: ModuleColors.finance),
                    SizedBox(width: 2),
                    Text('每日均摊', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                  ],
                ),
                Text('¥${adc.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ModuleColors.finance)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _assetIcon(String id) {
    const icons = {'laptop': '💻', 'chair': '🪑', 'camera': '📷', 'guitar': '🎸', 'tablet': '📱', 'car': '🚗'};
    return icons[id] ?? '📦';
  }
}
