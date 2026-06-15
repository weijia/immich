import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/providers/saved_server.provider.dart';
import 'package:logging/logging.dart';

/// Dialog for auto-reconnecting to server when IP changes
class AutoReconnectDialog extends HookConsumerWidget {
  final String? currentUrl;
  final Function(String)? onReconnected;

  const AutoReconnectDialog({
    super.key,
    this.currentUrl,
    this.onReconnected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedServer = ref.watch(savedServerProvider);
    final savedServerNotifier = ref.watch(savedServerProvider.notifier);
    final reconnectState = ref.watch(_reconnectStateProvider);
    final reconnectNotifier = ref.watch(_reconnectStateProvider.notifier);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync_problem),
          const SizedBox(width: 8),
          const Text('重新连接服务器'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server info
            if (savedServer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '原服务器 IP 地址已变化',
                      style: context.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${savedServer.serverName}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '旧地址: ${savedServer.serverUrl.replaceAll('/api', '')}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Searching status
            if (reconnectState.isSearching)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      '正在自动搜索新地址...',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Found new server
            if (reconnectState.newUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '找到服务器！',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '新地址: ${reconnectState.newUrl!.replaceAll('/api', '')}',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Not found
            if (reconnectState.notFound)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: context.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '未找到服务器',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请手动输入服务器地址',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Error
            if (reconnectState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  reconnectState.error!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        if (!reconnectState.isSearching && reconnectState.newUrl != null)
          ElevatedButton.icon(
            onPressed: () {
              if (onReconnected != null && reconnectState.newUrl != null) {
                onReconnected!(reconnectState.newUrl!);
              }
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.link),
            label: const Text('自动连接'),
          ),
        if (!reconnectState.isSearching && reconnectState.notFound)
          ElevatedButton.icon(
            onPressed: () => reconnectNotifier.reconnect(savedServerNotifier),
            icon: const Icon(Icons.refresh),
            label: const Text('重新搜索'),
          ),
      ],
    );
  }
}

/// Reconnect state
class ReconnectState {
  final bool isSearching;
  final String? newUrl;
  final bool notFound;
  final String? error;

  ReconnectState({
    this.isSearching = false,
    this.newUrl,
    this.notFound = false,
    this.error,
  });

  ReconnectState copyWith({
    bool? isSearching,
    String? newUrl,
    bool? notFound,
    String? error,
  }) {
    return ReconnectState(
      isSearching: isSearching ?? this.isSearching,
      newUrl: newUrl,
      notFound: notFound ?? this.notFound,
      error: error,
    );
  }
}

/// Reconnect state provider
final _reconnectStateProvider = StateNotifierProvider<_ReconnectStateNotifier, ReconnectState>((ref) {
  return _ReconnectStateNotifier();
});

class _ReconnectStateNotifier extends StateNotifier<ReconnectState> {
  final _log = Logger('ReconnectStateNotifier');

  _ReconnectStateNotifier() : super(ReconnectState());

  Future<void> reconnect(SavedServerNotifier savedServerNotifier) async {
    _log.info('[ReconnectStateNotifier] Starting reconnect');
    state = state.copyWith(isSearching: true, notFound: false, error: null);

    try {
      final newUrl = await savedServerNotifier.tryReconnect();

      if (newUrl != null) {
        _log.info('[ReconnectStateNotifier] Found new URL: $newUrl');
        state = state.copyWith(
          isSearching: false,
          newUrl: newUrl,
        );
      } else {
        _log.warning('[ReconnectStateNotifier] Server not found');
        state = state.copyWith(
          isSearching: false,
          notFound: true,
        );
      }
    } catch (e) {
      _log.severe('[ReconnectStateNotifier] Reconnect error: $e');
      state = state.copyWith(
        isSearching: false,
        error: '连接失败: $e',
      );
    }
  }
}

/// Helper function to show reconnect dialog
Future<bool?> showAutoReconnectDialog(
  BuildContext context,
  {Function(String)? onReconnected}
) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AutoReconnectDialog(
      onReconnected: onReconnected,
    ),
  );
}

/// Check if server is reachable and show reconnect dialog if needed
Future<String?> checkServerConnection(
  BuildContext context,
  WidgetRef ref,
) async {
  final savedServer = ref.read(savedServerProvider);
  if (savedServer == null) return null;

  // Try to ping the saved URL
  try {
    // Simple check - try to connect
    final uri = Uri.parse(savedServer.serverUrl);
    // For now, we'll just return the saved URL
    // In a real implementation, we would ping the server
    return savedServer.serverUrl;
  } catch (e) {
    // Server not reachable, show reconnect dialog
    final result = await showAutoReconnectDialog(
      context,
      onReconnected: (newUrl) {
        ref.read(savedServerProvider.notifier).updateServerUrl(newUrl);
      },
    );

    if (result == true) {
      return ref.read(savedServerProvider)?.serverUrl;
    }
    return null;
  }
}