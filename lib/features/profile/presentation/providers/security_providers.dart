import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecurityGateNotifier extends StateNotifier<bool> {
  SecurityGateNotifier() : super(false);

  void unlock() => state = true;
  void lock() => state = false;
}

final securityGateProvider =
    StateNotifierProvider<SecurityGateNotifier, bool>((ref) => SecurityGateNotifier());
