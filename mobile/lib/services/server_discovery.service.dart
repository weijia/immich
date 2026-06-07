import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// UDP Discovery Protocol for Immich Server
/// Discovers Immich servers on the local network via UDP broadcast
class ServerDiscoveryService {
  static const int discoveryPort = 2284;
  static const String broadcastAddress = '255.255.255.255';
  static const String discoverRequest = 'DISCOVER_IMMICH_SERVER';
  static const String responsePrefix = 'IMMICH_SERVER_RESPONSE:';

  /// Discover Immich servers on the local network
  /// Returns a list of discovered servers within [timeout]
  Future<List<DiscoveredServer>> discoverServers({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final results = <DiscoveredServer>[];

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Send discovery broadcast
      socket.send(
        utf8.encode(discoverRequest),
        InternetAddress(broadcastAddress),
        discoveryPort,
      );

      // Listen for responses with timeout
      final completer = Completer<void>();
      final subscription = socket.timeout(timeout).listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            final server = _parseResponse(response);
            if (server != null && !results.any((s) => s.url == server.url)) {
              results.add(server);
            }
          }
        }
      });

      // Wait for timeout or enough responses
      await completer.future;
      subscription.cancel();
      socket.close();
    } catch (e) {
      // Timeout or socket error - return what we have
      debugPrint('Discovery error: $e');
    }

    return results;
  }

  /// Parse a discovery response from the server
  DiscoveredServer? _parseResponse(String data) {
    try {
      if (!data.startsWith(responsePrefix)) return null;
      final jsonStr = data.substring(responsePrefix.length);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DiscoveredServer(
        url: json['serverUrl'] as String? ?? '',
        version: json['version'] as String? ?? '',
        name: json['serverName'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('Failed to parse discovery response: $e');
      return null;
    }
  }

  void debugPrint(String message) {
    // In production, this could use the app's logging system
    print('[ServerDiscovery] $message');
  }
}

/// Represents a discovered Immich server
class DiscoveredServer {
  final String url;
  final String version;
  final String name;
  final int timestamp;

  DiscoveredServer({
    required this.url,
    required this.version,
    required this.name,
    required this.timestamp,
  });

  @override
  String toString() => 'DiscoveredServer(url: $url, version: $version, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredServer &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}
