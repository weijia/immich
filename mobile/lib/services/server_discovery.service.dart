import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:immich_mobile/domain/models/server/saved_server.model.dart';
import 'package:immich_mobile/utils/signature_utils.dart';
import 'package:logging/logging.dart';

/// UDP Discovery Protocol for Immich Server
/// 
/// Supports protocol versions:
/// - v1.0: Basic discovery (DISCOVER_IMMICH_SERVER -> response)
/// - v2.0: Server ID matching (response includes serverId)
/// - v3.0: Token-based signing (request includes challenge nonce, response includes signature)
class ServerDiscoveryService {
  static const int discoveryPort = 2284;
  static const String broadcastAddress = '255.255.255.255';
  static const String discoverRequestV1 = 'DISCOVER_IMMICH_SERVER';
  static const String discoverRequestPrefixV3 = 'DISCOVER_IMMICH_SERVER:';
  static const String responsePrefix = 'IMMICH_SERVER_RESPONSE:';
  
  final _log = Logger('ServerDiscoveryService');
  
  // Client ID for v3.0 requests (generated once per session)
  final String _clientId = SignatureUtils.generateClientId();

  /// Discover Immich servers on the local network.
  /// 
  /// If [savedServer] is provided, will use v3.0 protocol with signature verification.
  /// Returns a list of discovered servers within [timeout].
  Future<List<DiscoveredServer>> discoverServers({
    SavedServer? savedServer,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final results = <DiscoveredServer>[];
    RawDatagramSocket? socket;
    StreamSubscription? subscription;

    try {
      _log.info('[ServerDiscoveryService] Binding UDP socket');
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _log.info('[ServerDiscoveryService] Socket bound to port ${socket.port}');

      // Determine which protocol version to use
      final request = _buildDiscoveryRequest(savedServer);
      final requestBytes = utf8.encode(request);
      
      _log.info('[ServerDiscoveryService] Sending discovery request: $request');
      socket.send(
        requestBytes,
        InternetAddress(broadcastAddress),
        discoveryPort,
      );
      _log.info('[ServerDiscoveryService] Sent broadcast to $broadcastAddress:$discoveryPort');

      // Listen for responses with timeout
      final completer = Completer<void>();
      int packetCount = 0;
      String? challengeNonce;

      // Extract nonce from request for verification
      if (request.startsWith(discoverRequestPrefixV3)) {
        final parts = request.substring(discoverRequestPrefixV3.length).split(':');
        if (parts.length >= 2) {
          challengeNonce = parts[1];
        }
      }

      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null) {
            packetCount++;
            final response = utf8.decode(datagram.data);
            _log.info('[ServerDiscoveryService] Received packet #$packetCount from ${datagram.address.address}:${datagram.port}');
            _log.fine('[ServerDiscoveryService] Raw response: $response');

            final server = _parseResponse(response, savedServer, challengeNonce);
            if (server != null) {
              _log.info('[ServerDiscoveryService] Parsed server: ${server.serverId ?? "no-id"}, url=${server.url}');
              if (!results.any((s) => s.url == server.url)) {
                results.add(server);
                _log.info('[ServerDiscoveryService] Added server to results (total: ${results.length})');
              } else {
                _log.fine('[ServerDiscoveryService] Duplicate server, skipping');
              }
            } else {
              _log.warning('[ServerDiscoveryService] Failed to parse response');
            }
          }
        }
      }, onError: (error) {
        _log.severe('[ServerDiscoveryService] Socket error: $error');
        if (!completer.isCompleted) completer.complete();
      }, onDone: () {
        _log.info('[ServerDiscoveryService] Socket done');
        if (!completer.isCompleted) completer.complete();
      });

      // Wait for timeout
      await Future.delayed(timeout);
      _log.info('[ServerDiscoveryService] Timeout reached, found ${results.length} server(s)');
      if (!completer.isCompleted) completer.complete();

      await subscription.cancel();
      socket.close();
    } catch (e, stackTrace) {
      _log.severe('[ServerDiscoveryService] Discovery error: $e');
      _log.severe('[ServerDiscoveryService] Stack trace: $stackTrace');
      try {
        await subscription?.cancel();
        socket?.close();
      } catch (_) {}
    }

    return results;
  }

  /// Build discovery request based on saved server.
  /// 
  /// If savedServer has serverToken, use v3.0 protocol.
  /// Otherwise, use v1.0 protocol.
  String _buildDiscoveryRequest(SavedServer? savedServer) {
    if (savedServer?.serverToken != null) {
      // v3.0 request with challenge nonce
      final nonce = SignatureUtils.generateChallengeNonce();
      return '$discoverRequestPrefixV3$_clientId:$nonce';
    } else {
      // v1.0 request
      return discoverRequestV1;
    }
  }

  /// Parse a discovery response from the server.
  /// 
  /// Supports v1.0, v2.0, and v3.0 response formats.
  DiscoveredServer? _parseResponse(
    String data,
    SavedServer? savedServer,
    String? challengeNonce,
  ) {
    try {
      if (!data.startsWith(responsePrefix)) {
        _log.warning('[ServerDiscoveryService] Response does not start with prefix');
        return null;
      }
      
      final jsonStr = data.substring(responsePrefix.length);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _log.fine('[ServerDiscoveryService] JSON keys: ${json.keys.toList()}');
      
      // Check for v3.0 response (has signature)
      final signature = json['signature'] as String?;
      final serverId = json['serverId'] as String?;
      final serverName = json['serverName'] as String? ?? 'Immich Server';
      final serverUrl = json['serverUrl'] as String? ?? '';
      final version = json['version'] as String? ?? '3.0.0';
      final timestamp = json['timestamp'] as int? ?? 0;
      final responseNonce = json['challengeNonce'] as String?;
      
      // v3.0 verification
      if (signature != null && savedServer?.serverToken != null && challengeNonce != null) {
        _log.info('[ServerDiscoveryService] v3.0 response detected, verifying signature');
        
        // Check nonce matches
        if (responseNonce != challengeNonce) {
          _log.warning('[ServerDiscoveryService] Challenge nonce mismatch');
          return null;
        }
        
        // Verify signature
        final verified = SignatureUtils.verifySignature(
          savedServer!.serverToken!,
          serverId!,
          serverUrl,
          timestamp,
          challengeNonce,
          signature,
        );
        
        if (!verified) {
          _log.warning('[ServerDiscoveryService] Signature verification failed');
          return null;
        }
        
        _log.info('[ServerDiscoveryService] Signature verified successfully');
        
        return DiscoveredServer(
          url: serverUrl,
          version: version,
          name: serverName,
          timestamp: timestamp,
          serverId: serverId,
          signature: signature,
          isVerified: true,
        );
      }
      
      // v2.0 response (has serverId but no signature)
      if (serverId != null) {
        _log.info('[ServerDiscoveryService] v2.0 response detected');
        return DiscoveredServer(
          url: serverUrl,
          version: version,
          name: serverName,
          timestamp: timestamp,
          serverId: serverId,
          isVerified: false,
        );
      }
      
      // v1.0 response
      _log.info('[ServerDiscoveryService] v1.0 response detected');
      return DiscoveredServer(
        url: serverUrl,
        version: version,
        name: serverName,
        timestamp: timestamp,
        isVerified: false,
      );
    } catch (e, stackTrace) {
      _log.severe('[ServerDiscoveryService] Failed to parse response: $e');
      _log.severe('[ServerDiscoveryService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Try to reconnect to saved server.
  /// 
  /// 1. Try saved URL first
  /// 2. If fails, send discovery broadcast
  /// 3. Match serverId if found
  /// 4. Return new URL if matched
  Future<String?> tryReconnect(SavedServer savedServer) async {
    _log.info('[ServerDiscoveryService] Trying to reconnect to saved server: ${savedServer.serverId}');
    
    // First, try saved URL
    try {
      final socket = await Socket.connect(
        savedServer.serverUrl.split('/').first.split(':').first,
        int.parse(savedServer.serverUrl.split(':').last.split('/').first),
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      _log.info('[ServerDiscoveryService] Saved URL still works');
      return savedServer.serverUrl;
    } catch (e) {
      _log.info('[ServerDiscoveryService] Saved URL failed, starting discovery');
    }
    
    // Send discovery
    final servers = await discoverServers(savedServer: savedServer);
    
    // Find matching server
    for (final server in servers) {
      if (server.serverId == savedServer.serverId) {
        _log.info('[ServerDiscoveryService] Found matching server: ${server.url}');
        return server.url;
      }
    }
    
    _log.warning('[ServerDiscoveryService] No matching server found');
    return null;
  }
}

/// Represents a discovered Immich server
class DiscoveredServer {
  final String url;
  final String version;
  final String name;
  final int timestamp;
  final String? serverId;
  final String? signature;
  final bool isVerified;

  DiscoveredServer({
    required this.url,
    required this.version,
    required this.name,
    required this.timestamp,
    this.serverId,
    this.signature,
    this.isVerified = false,
  });

  @override
  String toString() => 'DiscoveredServer(url: $url, version: $version, name: $name, serverId: $serverId, isVerified: $isVerified)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredServer &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}