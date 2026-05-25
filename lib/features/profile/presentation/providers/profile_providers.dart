import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/event_bus/bus.dart';
import '../../../../core/event_bus/events.dart';

class SecureDocumentItem {
  final String id;
  final String type;
  final String title;
  final String encryptedValue;
  final DateTime expiryDate;
  final int alertOffsetDays;

  const SecureDocumentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.encryptedValue,
    required this.expiryDate,
    this.alertOffsetDays = 30,
  });
}

class MemorialItem {
  final String id;
  final String name;
  final DateTime date;
  final int advanceDays;
  final double? budget;

  const MemorialItem({
    required this.id,
    required this.name,
    required this.date,
    this.advanceDays = 7,
    this.budget,
  });
}

class RelationshipItem {
  final String id;
  final String name;
  final String relationType;
  final DateTime lastInteraction;
  final int warmthScore;

  const RelationshipItem({
    required this.id,
    required this.name,
    required this.relationType,
    required this.lastInteraction,
    required this.warmthScore,
  });

  RelationshipItem copyWith({DateTime? lastInteraction, int? warmthScore}) {
    return RelationshipItem(
      id: id,
      name: name,
      relationType: relationType,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      warmthScore: warmthScore ?? this.warmthScore,
    );
  }
}

class SecureDocumentsNotifier extends StateNotifier<List<SecureDocumentItem>> {
  SecureDocumentsNotifier() : super(_mockDocs);

  void addDocument(SecureDocumentItem item) => state = [...state, item];

  static final _mockDocs = [
    SecureDocumentItem(
      id: 'doc1',
      type: 'PASSPORT',
      title: '护照',
      encryptedValue: 'ENC:UD1234567',
      expiryDate: DateTime.now().add(const Duration(days: 45)),
    ),
    SecureDocumentItem(
      id: 'doc2',
      type: 'ID_CARD',
      title: '身份证',
      encryptedValue: 'ENC:110101199001010000',
      expiryDate: DateTime.now().add(const Duration(days: 780)),
    ),
  ];
}

class MemorialNotifier extends StateNotifier<List<MemorialItem>> {
  MemorialNotifier() : super(_mockMemorials);

  void addMemorial(MemorialItem item) {
    state = [...state, item];
    globalEventBus.fire(MemorialTodoEvent(
      memorialId: item.id,
      title: '准备：${item.name}',
      targetDate: item.date.subtract(Duration(days: item.advanceDays)),
    ));
  }

  static final _mockMemorials = [
    MemorialItem(id: 'm1', name: '妈妈生日', date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 6), budget: 500),
    MemorialItem(id: 'm2', name: '结婚纪念日', date: DateTime(DateTime.now().year, DateTime.now().month + 1, 12), budget: 1200),
  ];
}

class RelationshipNotifier extends StateNotifier<List<RelationshipItem>> {
  RelationshipNotifier() : super(_mockRelationships);

  void logInteraction(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(lastInteraction: DateTime.now(), warmthScore: (item.warmthScore + 8).clamp(0, 100))
        else
          item,
    ];
  }

  static final _mockRelationships = [
    RelationshipItem(id: 'r1', name: '阿杰', relationType: '好友', lastInteraction: DateTime.now().subtract(const Duration(days: 2)), warmthScore: 88),
    RelationshipItem(id: 'r2', name: '妈妈', relationType: '家人', lastInteraction: DateTime.now().subtract(const Duration(days: 7)), warmthScore: 74),
    RelationshipItem(id: 'r3', name: '小李', relationType: '同事', lastInteraction: DateTime.now().subtract(const Duration(days: 18)), warmthScore: 42),
  ];
}

final secureDocumentsNotifierProvider =
    StateNotifierProvider<SecureDocumentsNotifier, List<SecureDocumentItem>>((ref) => SecureDocumentsNotifier());

final secureDocumentsProvider = Provider<List<SecureDocumentItem>>((ref) => ref.watch(secureDocumentsNotifierProvider));

final memorialNotifierProvider =
    StateNotifierProvider<MemorialNotifier, List<MemorialItem>>((ref) => MemorialNotifier());

final memorialProvider = Provider<List<MemorialItem>>((ref) => ref.watch(memorialNotifierProvider));

final relationshipNotifierProvider =
    StateNotifierProvider<RelationshipNotifier, List<RelationshipItem>>((ref) => RelationshipNotifier());

final relationshipProvider = Provider<List<RelationshipItem>>((ref) => ref.watch(relationshipNotifierProvider));
