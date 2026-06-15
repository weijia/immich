import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/providers/saved_server.provider.dart';
import 'package:immich_mobile/domain/models/server/saved_server.model.dart';
import 'package:immich_mobile/services/server_discovery.service.dart';
import 'package:logging/logging.dart';

/// Dialog for discovering Immich servers on the local network
class ServerDiscoveryDialog extends HookConsumerWidget {
  final Function(DiscoveredServer)? onServerSelected;
  final SavedServer? savedServer;

  const ServerDiscoveryDialog({
    super.key,
    this.onServerSelected,
    this.savedServer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryService = ref.watch(serverDiscoveryProvider);
    final discoveryState = ref.watch(_discoveryStateProvider);
    final discoveryNotifier = ref.watch(_discoveryStateProvider.notifier);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.search),
          const SizedBox(width: 8),
          const Text('发现服务器'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status text
            if (discoveryState.isDiscovering)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '正在搜索网络中的 Immich 服务器...',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Error message
            if (discoveryState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  discoveryState.error!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ),

            // Server list
            if (discoveryState.servers.isNotEmpty)
              ...discoveryState.servers.map((server) => _ServerListTile(
                    server: server,
                    isSelected: savedServer?.serverId == server.serverId,
                    onTap: () {
                      if (onServerSelected != null) {
                        onServerSelected!(server);
                      }
                      Navigator.of(context).pop();
                    },
                  )),

            // No servers found
            if (!discoveryState.isDiscovering && discoveryState.servers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '未发现服务器',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceSecondary,
                  ),
                ),
              ),

            // Manual input hint
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '未找到服务器？请手动输入服务器地址：',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (!discoveryState.isDiscovering)
          ElevatedButton.icon(
            onPressed: () => discoveryNotifier.discover(
              discoveryService,
              savedServer: savedServer,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('重新搜索'),
          ),
      ],
    );
  }
}

/// Server list tile widget
class _ServerListTile extends StatelessWidget {
  final DiscoveredServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServerListTile({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? context.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Server icon
              Icon(
                Icons.dns,
                size: 32,
                color: isSelected
                    ? context.colorScheme.onPrimaryContainer
                    : context.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),

              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? context.colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      server.url.replaceAll('/api', ''),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? context.colorScheme.onPrimaryContainer
                            : context.colorScheme.onSurfaceSecondary,
                      ),
                    ),
                    if (server.serverId != null)
                      Text(
                        'ID: ${server.serverId!.substring(0, 8)}...',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? context.colorScheme.onPrimaryContainer
                              : context.colorScheme.onSurfaceSecondary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),

              // Verified badge
              if (server.isVerified)
                Icon(
                  Icons.verified,
                  color: context.colorScheme.primary,
                  size: 20,
                ),

              // Select button
              if (!isSelected)
                Icon(
                  Icons.arrow_forward_ios,
                  color: context.colorScheme.onSurfaceSecondary,
                  size: 16,
                ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: context.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Discovery state
class DiscoveryState {
  final bool isDiscovering;
  final List<DiscoveredServer> servers;
  final String? error;

  DiscoveryState({
    this.isDiscovering = false,
    List<DiscoveredServer>? servers,
    this.error,
  }) : servers = servers ?? [];

  DiscoveryState copyWith({
    bool? isDiscovering,
    List<DiscoveredServer>? servers,
    String? error,
  }) {
    return DiscoveryState(
      isDiscovering: isDiscovering ?? this.isDiscovering,
      servers: servers ?? this.servers,
      error: error,
    );
  }
}

/// Discovery state provider
final _discoveryStateProvider = StateNotifierProvider<_DiscoveryStateNotifier, DiscoveryState>((ref) {
  return _DiscoveryStateNotifier();
});

class _DiscoveryStateNotifier extends StateNotifier<DiscoveryState> {
  final _log = Logger('DiscoveryStateNotifier');

  _DiscoveryStateNotifier() : super(DiscoveryState());

  Future<void> discover(
    ServerDiscoveryService discoveryService,
    {SavedServer? savedServer}
  ) async {
    _log.info('[DiscoveryStateNotifier] Starting discovery');
    state = state.copyWith(isDiscovering: true, error: null);

    try {
      final servers = await discoveryService.discoverServers(
        savedServer: savedServer,
        timeout: const Duration(seconds: 5),
      );

      _log.info('[DiscoveryStateNotifier] Found ${servers.length} servers');
      state = state.copyWith(
        isDiscovering: false,
        servers: servers,
      );
    } catch (e) {
      _log.severe('[DiscoveryStateNotifier] Discovery error: $e');
      state = state.copyWith(
        isDiscovering: false,
        error: '发现失败: $e',
      );
    }
  }
}

/// Helper function to show discovery dialog
Future<DiscoveredServer?> showServerDiscoveryDialog(
  BuildContext context,
  {SavedServer? savedServer}
) async {
  return await showDialog<DiscoveredServer>(
    context: context,
    builder: (context) => ServerDiscoveryDialog(
      savedServer: savedServer,
    ),
  );
}