import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/server/saved_server.model.dart';
import 'package:immich_mobile/domain/services/saved_server_storage.service.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/server_discovery.service.dart';
import 'package:openapi/api.dart';
import 'package:logging/logging.dart';

/// Provider for SavedServerStorageService
final savedServerStorageProvider = Provider<SavedServerStorageService>((ref) {
  return SavedServerStorageService();
});

/// Provider for managing saved server state
final savedServerProvider = StateNotifierProvider<SavedServerNotifier, SavedServer?>((ref) {
  return SavedServerNotifier(ref.watch(savedServerStorageProvider));
});

/// Provider for ServerDiscoveryService
final serverDiscoveryProvider = Provider<ServerDiscoveryService>((ref) {
  return ServerDiscoveryService();
});

class SavedServerNotifier extends StateNotifier<SavedServer?> {
  final SavedServerStorageService _storageService;
  final _log = Logger('SavedServerNotifier');

  SavedServerNotifier(this._storageService) : super(null) {
    _loadSavedServer();
  }

  /// Load saved server from storage
  Future<void> _loadSavedServer() async {
    _log.info('[SavedServerNotifier] Loading saved server');
    final savedServer = await _storageService.getSavedServer();
    state = savedServer;
    if (savedServer != null) {
      _log.info('[SavedServerNotifier] Loaded: ${savedServer.serverId}');
    } else {
      _log.info('[SavedServerNotifier] No saved server found');
    }
  }

  /// Save server information after successful login
  Future<void> saveServer({
    required String serverId,
    required String serverName,
    required String serverUrl,
    String? serverToken,
  }) async {
    _log.info('[SavedServerNotifier] Saving server: $serverId');
    
    final server = SavedServer(
      serverId: serverId,
      serverName: serverName,
      serverUrl: serverUrl,
      serverToken: serverToken,
      lastConnected: DateTime.now(),
    );
    
    await _storageService.saveServer(server);
    state = server;
    
    _log.info('[SavedServerNotifier] Server saved successfully');
  }

  /// Update server URL (when IP changes)
  Future<void> updateServerUrl(String newUrl) async {
    if (state == null) return;
    
    _log.info('[SavedServerNotifier] Updating URL: $newUrl');
    
    final updated = state!.copyWith(
      serverUrl: newUrl,
      lastConnected: DateTime.now(),
    );
    
    await _storageService.saveServer(updated);
    state = updated;
    
    _log.info('[SavedServerNotifier] URL updated');
  }

  /// Exchange server token after login
  Future<String?> exchangeServerToken(String accessToken, String clientId) async {
    _log.info('[SavedServerNotifier] Exchanging server token');
    
    try {
      // Call token-exchange API
      final api = ApiService();
      // Note: This requires the API to be set up with the current server URL
      // For now, we'll skip this if API is not configured
      
      _log.info('[SavedServerNotifier] Token exchange not implemented yet');
      return null;
    } catch (e) {
      _log.severe('[SavedServerNotifier] Token exchange failed: $e');
      return null;
    }
  }

  /// Try to reconnect to saved server
  /// Returns new URL if found, null if not found
  Future<String?> tryReconnect() async {
    if (state == null) {
      _log.warning('[SavedServerNotifier] No saved server to reconnect');
      return null;
    }
    
    final savedServer = state!;
    _log.info('[SavedServerNotifier] Trying to reconnect to: ${savedServer.serverId}');
    
    final discoveryService = ServerDiscoveryService();
    final newUrl = await discoveryService.tryReconnect(savedServer);
    
    if (newUrl != null) {
      _log.info('[SavedServerNotifier] Found new URL: $newUrl');
      await updateServerUrl(newUrl);
      return newUrl;
    }
    
    _log.warning('[SavedServerNotifier] Reconnect failed');
    return null;
  }

  /// Clear saved server
  Future<void> clearSavedServer() async {
    _log.info('[SavedServerNotifier] Clearing saved server');
    await _storageService.clearSavedServer();
    state = null;
    _log.info('[SavedServerNotifier] Saved server cleared');
  }

  /// Check if server is saved
  bool hasSavedServer() => state != null;

  /// Get server ID
  String? getServerId() => state?.serverId;

  /// Get server URL
  String? getServerUrl() => state?.serverUrl;

  /// Get server name
  String? getServerName() => state?.serverName;
}