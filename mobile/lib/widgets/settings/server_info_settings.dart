import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/providers/saved_server.provider.dart';
import 'package:immich_mobile/widgets/dialog/server_discovery_dialog.dart';
import 'package:immich_mobile/widgets/dialog/auto_reconnect_dialog.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:logging/logging.dart';

/// Server information settings section
class ServerInfoSettings extends HookConsumerWidget {
  const ServerInfoSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedServer = ref.watch(savedServerProvider);
    final savedServerNotifier = ref.watch(savedServerProvider.notifier);
    final _log = Logger('ServerInfoSettings');

    return ListView(
      children: [
        // Server info card
        if (savedServer != null)
          ServerInfoCard(
            title: '当前服务器',
            subtitle: savedServer.serverName,
            icon: Icons.dns_rounded,
            children: [
              // Server name
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('服务器名称'),
                subtitle: Text(savedServer.serverName),
              ),
              
              // Server URL
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('服务器地址'),
                subtitle: Text(
                  savedServer.serverUrl.replaceAll('/api', ''),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceSecondary,
                  ),
                ),
              ),
              
              // Server ID
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Server ID'),
                subtitle: Text(
                  savedServer.serverId.length > 20
                      ? '${savedServer.serverId.substring(0, 8)}...${savedServer.serverId.substring(savedServer.serverId.length - 8)}'
                      : savedServer.serverId,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceSecondary,
                  ),
                ),
              ),
              
              // Security status
              ListTile(
                leading: Icon(
                  savedServer.serverToken != null
                      ? Icons.verified_user
                      : Icons.warning_amber,
                  color: savedServer.serverToken != null
                      ? context.colorScheme.primary
                      : context.colorScheme.error,
                ),
                title: const Text('安全验证'),
                subtitle: Text(
                  savedServer.serverToken != null
                      ? '已启用 (v3.0 签名验证)'
                      : '未启用',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: savedServer.serverToken != null
                        ? context.colorScheme.primary
                        : context.colorScheme.error,
                  ),
                ),
              ),
              
              // Last connected
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('最后连接'),
                subtitle: Text(
                  '${savedServer.lastConnected.toLocal().toString().split('.')[0]}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceSecondary,
                  ),
                ),
              ),
              
              const Divider(),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Re-discover button
                    ElevatedButton.icon(
                      onPressed: () async {
                        _log.info('[ServerInfoSettings] Re-discover button pressed');
                        final server = await showServerDiscoveryDialog(
                          context,
                          savedServer: savedServer,
                        );
                        if (server != null) {
                          await savedServerNotifier.saveServer(
                            serverId: server.serverId ?? savedServer.serverId,
                            serverName: server.name,
                            serverUrl: server.url,
                          );
                          // Activate the newly discovered server: resolve and switch
                          // the active endpoint so the app actually connects to it.
                          try {
                            await ApiService().resolveAndSetEndpoint(server.url);
                          } catch (e) {
                            _log.warning('[ServerInfoSettings] Failed to resolve new endpoint, using raw URL: $e');
                            await Store.put(StoreKey.serverEndpoint, server.url);
                            ApiService().setEndpoint(server.url);
                          }
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('重新发现服务器'),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Clear server info button
                    OutlinedButton.icon(
                      onPressed: () async {
                        _log.info('[ServerInfoSettings] Clear button pressed');
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('确认清除'),
                            content: const Text('清除服务器信息后，下次登录需要重新发现服务器。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('确认'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await savedServerNotifier.clearSavedServer();
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清除服务器信息'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          // No saved server
          ServerInfoCard(
            title: '服务器信息',
            subtitle: '未保存服务器',
            icon: Icons.dns_rounded,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '尚未保存服务器信息。登录后，服务器信息将自动保存，以便下次自动连接。',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final server = await showServerDiscoveryDialog(context);
                        if (server != null) {
                          // Navigate to login with discovered server
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('发现服务器'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        
        // Auto reconnect section
        ServerInfoCard(
          title: '自动重连',
          subtitle: 'IP 变化时自动发现新地址',
          icon: Icons.sync_problem,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('自动重连功能'),
              subtitle: Text(
                '当服务器 IP 地址变化时，客户端会自动搜索并验证新地址。',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceSecondary,
                ),
              ),
            ),
            
            if (savedServer != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _log.info('[ServerInfoSettings] Test reconnect button pressed');
                    await showAutoReconnectDialog(
                      context,
                      onReconnected: (newUrl) {
                        savedServerNotifier.updateServerUrl(newUrl);
                      },
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('测试自动重连'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Simple settings info card widget
class ServerInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const ServerInfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: Icon(icon, color: context.primaryColor),
            title: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceSecondary,
              ),
            ),
          ),
          
          const Divider(),
          
          // Content
          ...children,
        ],
      ),
    );
  }
}