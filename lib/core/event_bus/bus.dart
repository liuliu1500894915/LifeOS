import 'package:event_bus/event_bus.dart';

/// Global event bus instance for cross-module communication.
///
/// Usage:
/// ```dart
/// // Subscribe (typically in a provider or initState)
/// streamSubscription = globalEventBus.on<MemorialTodoEvent>().listen((e) {
///   // handle event
/// });
///
/// // Emit
/// globalEventBus.fire(MemorialTodoEvent(...));
/// ```
final globalEventBus = EventBus();
