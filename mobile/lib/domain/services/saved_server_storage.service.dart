import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:immich_mobile/domain/models/server/saved_server.model.dart';

/// Service for securely storing and retrieving saved server information.
/// 
/// Uses flutter_secure_storage for secure token storage:
/// - iOS: Keychain
/// - Android: Keystore (encrypted)
class SavedServerStorageService {
  static const String _savedServerKey = 'saved_server_info';
  static const String _serverTokenKeyPrefix = 'server_token_';
  
  final FlutterSecureStorage _secureStorage;
  final _log = Logger('SavedServerStorageService');

  SavedServerStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Save server information.
  /// 
  /// The serverToken is stored separately in secure storage keyed by serverId.
  Future<void> saveServer(SavedServer server) async {
    _log.info('[SavedServerStorageService] Saving server: ${server.serverId}');
    
    try {
      // Save server info (without token) to regular storage
      final serverInfo = server.copyWith(serverToken: null);
      await _secureStorage.write(
        key: _savedServerKey,
        value: serverInfo.toJsonString(),
      );
      
      // Save serverToken separately if provided
      if (server.serverToken != null) {
        await saveServerToken(server.serverId, server.serverToken!);
      }
      
      _log.info('[SavedServerStorageService] Server saved successfully');
    } catch (e) {
      _log.severe('[SavedServerStorageService] Failed to save server: $e');
      rethrow;
    }
  }

  /// Get saved server information.
  /// 
  /// Returns null if no server is saved.
  Future<SavedServer?> getSavedServer() async {
    _log.info('[SavedServerStorageService] Getting saved server');
    
    try {
      final serverJson = await _secureStorage.read(key: _savedServerKey);
      if (serverJson == null) {
        _log.info('[SavedServerStorageService] No saved server found');
        return null;
      }
      
      final server = SavedServer.fromJsonString(serverJson);
      
      // Retrieve serverToken if available
      final serverToken = await getServerToken(server.serverId);
      
      if (serverToken != null) {
        return server.copyWith(serverToken: serverToken);
      }
      
      return server;
    } catch (e) {
      _log.severe('[SavedServerStorageService] Failed to get saved server: $e');
      return null;
    }
  }

  /// Save server token for a specific server.
  Future<void> saveServerToken(String serverId, String serverToken) async {
    _log.info('[SavedServerStorageService] Saving server token for: $serverId');
    
    try {
      await _secureStorage.write(
        key: '${_serverTokenKeyPrefix}${serverId}',
        value: serverToken,
      );
      _log.info('[SavedServerStorageService] Server token saved');
    } catch (e) {
      _log.severe('[SavedServerStorageService] Failed to save server token: $e');
      rethrow;
    }
  }

  /// Get server token for a specific server.
  Future<String?> getServerToken(String serverId) async {
    _log.info('[SavedServerStorageService] Getting server token for: $serverId');
    
    try {
      final token = await _secureStorage.read(
        key: '${_serverTokenKeyPrefix}${serverId}',
      );
      
      if (token != null) {
        _log.info('[SavedServerStorageService] Server token found');
      } else {
        _log.info('[SavedServerStorageService] No server token found');
      }
      
      return token;
    } catch (e) {
      _log.severe('[SavedServerStorageService] Failed to get server token: $e');
      return null;
    }
  }

  /// Update server URL (when IP changes).
  Future<void> updateServerUrl(String newUrl) async {
    _log.info('[SavedServerStorageService] Updating server URL to: $newUrl');
    
    final server = await getSavedServer();
    if (server == null) {
      _log.warning('[SavedServerStorageService] No saved server to update');
      return;
    }
    
    await saveServer(server.copyWith(
      serverUrl: newUrl,
      lastConnected: DateTime.now(),
    ));
    
    _log.info('[SavedServerStorageService] Server URL updated');
  }

  /// Update last connected time.
  Future<void> updateLastConnected() async {
    final server = await getSavedServer();
    if (server == null) {
      _log.warning('[SavedServerStorageService] No saved server to update');
      return;
    }
    
    await saveServer(server.copyWith(
      lastConnected: DateTime.now(),
    ));
  }

  /// Clear all saved server information.
  Future<void> clearSavedServer() async {
    _log.info('[SavedServerStorageService] Clearing saved server');
    
    try {
      final server = await getSavedServer();
      
      // Delete server info
      await _secureStorage.delete(key: _savedServerKey);
      
      // Delete server token if exists
      if (server != null) {
        await _secureStorage.delete(
          key: '${_serverTokenKeyPrefix}${server.serverId}',
        );
      }
      
      _log.info('[SavedServerStorageService] Saved server cleared');
    } catch (e) {
      _log.severe('[SavedServerStorageService] Failed to clear saved server: $e');
      rethrow;
    }
  }

  /// Check if a server is saved.
  Future<bool> hasSavedServer() async {
    final server = await getSavedServer();
    return server != null;
  }
}