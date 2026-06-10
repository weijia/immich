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

    RawDatagramSocket? socket;
    StreamSubscription? subscription;

    try {
      _log('Binding UDP socket to any IPv4 port');
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _log('Socket bound to port ${socket.port}, broadcast enabled');

      // Send discovery broadcast
      final requestBytes = utf8.encode(discoverRequest);
      socket.send(
        requestBytes,
        InternetAddress(broadcastAddress),
        discoveryPort,
      );
      _log('Sent discovery broadcast to $broadcastAddress:$discoveryPort (${requestBytes.length} bytes)');

      // Listen for responses with timeout
      final completer = Completer<void>();
      int packetCount = 0;

      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null) {
            packetCount++;
            final response = utf8.decode(datagram.data);
            _log('Received packet #$packetCount from ${datagram.address.address}:${datagram.port} (${response.length} bytes)');
            _log('Raw response: ${response.length > 200 ? response.substring(0, 200) : response}');

            final server = _parseResponse(response);
            if (server != null) {
              _log('Parsed server: url=${server.url}, version=${server.version}, name=${server.name}');
              if (!results.any((s) => s.url == server.url)) {
                results.add(server);
                _log('Added server to results (total: ${results.length})');
              } else {
                _log('Duplicate server, skipping');
              }
            } else {
              _log('Failed to parse response as server');
            }
          }
        }
      }, onError: (error) {
        _log('Socket error: $error');
        if (!completer.isCompleted) completer.complete();
      }, onDone: () {
        _log('Socket done');
        if (!completer.isCompleted) completer.complete();
      });

      // Wait for timeout
      await Future.delayed(timeout);
      _log('Timeout reached after $timeout, received $packetCount packets, found ${results.length} server(s)');
      if (!completer.isCompleted) completer.complete();

      await subscription.cancel();
      socket.close();
    } catch (e, stack) {
      _log('Discovery error: $e');
      _log('Stack: $stack');
      try {
        await subscription?.cancel();
        socket?.close();
      } catch (_) {}
    }

    _log('Discovery complete, returning ${results.length} server(s)');
    return results;
  }

  /// Parse a discovery response from the server
  DiscoveredServer? _parseResponse(String data) {
    try {
      _log('Parsing response, length=${data.length}, starts with prefix=${data.startsWith(responsePrefix)}');
      if (!data.startsWith(responsePrefix)) {
        _log('Response does not start with "$responsePrefix", actual start: "${data.substring(0, data.length > 30 ? 30 : data.length)}"');
        return null;
      }
      final jsonStr = data.substring(responsePrefix.length);
      _log('JSON string: $jsonStr');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _log('Decoded JSON keys: ${json.keys.toList()}');
      return DiscoveredServer(
        url: json['serverUrl'] as String? ?? '',
        version: json['version'] as String? ?? '',
        name: json['serverName'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );
    } catch (e, stack) {
      _log('Failed to parse discovery response: $e');
      _log('Stack: $stack');
      return null;
    }
  }

  void _log(String message) {
    // Use print for debug console output
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
