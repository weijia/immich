import 'dart:convert';

/// Saved server information for auto-reconnect
class SavedServer {
  final String serverId;
  final String serverName;
  final String serverUrl;
  final String? serverToken;
  final DateTime lastConnected;

  const SavedServer({
    required this.serverId,
    required this.serverName,
    required this.serverUrl,
    this.serverToken,
    required this.lastConnected,
  });

  factory SavedServer.fromJson(Map<String, dynamic> json) {
    return SavedServer(
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      serverUrl: json['serverUrl'] as String,
      serverToken: json['serverToken'] as String?,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'serverName': serverName,
      'serverUrl': serverUrl,
      'serverToken': serverToken,
      'lastConnected': lastConnected.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory SavedServer.fromJsonString(String jsonString) {
    return SavedServer.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  SavedServer copyWith({
    String? serverId,
    String? serverName,
    String? serverUrl,
    String? serverToken,
    DateTime? lastConnected,
  }) {
    return SavedServer(
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      serverUrl: serverUrl ?? this.serverUrl,
      serverToken: serverToken ?? this.serverToken,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  @override
  String toString() {
    return 'SavedServer(serverId: $serverId, serverName: $serverName, serverUrl: $serverUrl, hasToken: ${serverToken != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedServer && other.serverId == serverId;
  }

  @override
  int get hashCode => serverId.hashCode;
}