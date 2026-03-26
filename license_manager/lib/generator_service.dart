import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

class GeneratorService {
  // MUST MATCH THE MAIN APP'S SHARED SECRET
  static const String _keyString = 'sathu_sys_erp_secure_key_32bytes'; 
  static const String _ivString = 'sathu_sys_iv_vec';

  /// Generates an encrypted product key for a specific Device ID and Expiry Date.
  static String generateKey({
    required String deviceId, 
    required DateTime expiry,
    String? licensedTo,
  }) {
    final Map<String, dynamic> data = {
      'deviceId': deviceId.trim().toUpperCase(),
      'expiry': expiry.toIso8601String(),
      'issued_at': DateTime.now().toIso8601String(),
      'owner': licensedTo ?? "Unknown Customer",
    };

    final jsonStr = jsonEncode(data);
    final key = encrypt.Key.fromUtf8(_keyString);
    final iv = encrypt.IV.fromUtf8(_ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // We use encryptToBase64 for the final result
    return encrypter.encrypt(jsonStr, iv: iv).base64;
  }
}
