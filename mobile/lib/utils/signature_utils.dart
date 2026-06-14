import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

/// Utility class for HMAC-SHA256 signature verification.
/// 
/// Used for verifying v3.0 discovery protocol responses.
class SignatureUtils {
  static final _log = Logger('SignatureUtils');

  /// Compute HMAC-SHA256 signature.
  /// 
  /// Returns hex-encoded signature string.
  static String computeHmacSha256Hex(String key, String data) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    
    return digest.toString();
  }

  /// Verify HMAC-SHA256 signature.
  /// 
  /// Returns true if signature matches.
  static bool verifySignature(
    String serverToken,
    String serverId,
    String serverUrl,
    int timestamp,
    String challengeNonce,
    String receivedSignature,
  ) {
    _log.info('[SignatureUtils] Verifying signature');
    _log.fine('[SignatureUtils] serverId=$serverId, serverUrl=$serverUrl, timestamp=$timestamp, nonce=$challengeNonce');
    
    // Check timestamp is within ±30 seconds
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timestampDiff = now - timestamp;
    
    if (timestampDiff.abs() > 30) {
      _log.warning('[SignatureUtils] Timestamp too old: diff=$timestampDiff seconds');
      return false;
    }
    
    // Compute expected signature
    final dataToSign = '$serverId|$serverUrl|$timestamp|$challengeNonce';
    _log.fine('[SignatureUtils] Data to sign: $dataToSign');
    
    final expectedSignature = computeHmacSha256Hex(serverToken, dataToSign);
    _log.fine('[SignatureUtils] Expected signature: $expectedSignature');
    _log.fine('[SignatureUtils] Received signature: $receivedSignature');
    
    // Compare signatures (case-insensitive)
    final matches = expectedSignature.toLowerCase() == receivedSignature.toLowerCase();
    
    if (matches) {
      _log.info('[SignatureUtils] Signature verified successfully');
    } else {
      _log.warning('[SignatureUtils] Signature mismatch');
    }
    
    return matches;
  }

  /// Generate random challenge nonce.
  /// 
  /// Returns a random string for use in discovery requests.
  static String generateChallengeNonce() {
    final random = DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecondsSinceEpoch % 10000).toString();
    final bytes = utf8.encode(random);
    final digest = sha256.convert(bytes);
    return 'nonce-${digest.toString().substring(0, 16)}';
  }

  /// Generate client ID.
  /// 
  /// Returns a unique client identifier.
  static String generateClientId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000).toString();
    return 'client-$timestamp-$random';
  }
}