import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Reusable empty state placeholder.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable loading state with optional skeleton.
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable error state with retry action.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ModuleColors.statusCritical.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: ModuleColors.statusCritical,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Switches between loading / error / content / empty states.
class AsyncStateSwitcher<T> extends StatelessWidget {
  const AsyncStateSwitcher({
    super.key,
    required this.value,
    required this.builder,
    this.loadingMessage,
    this.errorMessage,
    this.emptyMessage,
    this.onRetry,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String? loadingMessage;
  final String? errorMessage;
  final String? emptyMessage;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) {
        final empty = isEmpty?.call(data) ?? false;
        if (empty) {
          return EmptyStateWidget(
            message: emptyMessage ?? '暂无数据',
            onAction: onRetry,
            actionLabel: onRetry != null ? '刷新' : null,
          );
        }
        return builder(data);
      },
      loading: () => LoadingStateWidget(message: loadingMessage),
      error: (error, stack) => ErrorStateWidget(
        message: errorMessage ?? '数据加载失败: $error',
        onRetry: onRetry,
      ),
    );
  }
}
