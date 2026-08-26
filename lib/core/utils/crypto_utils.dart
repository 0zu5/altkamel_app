import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

class CryptoUtils {
  /// Replicates CryptoJS AES encryption (OpenSSL format: Salted__ + salt + ciphertext)
  static String encryptAESCryptoJS(String plainText, String passphrase) {
    try {
      // Generate an 8-byte random salt
      final salt = encrypt_lib.SecureRandom(8).bytes;

      // Derive Key and IV using MD5 (matches PHP evpBytesToKey)
      final keyAndIV = _deriveKeyAndIV(passphrase, salt);
      final key = encrypt_lib.Key(keyAndIV.key);
      final iv = encrypt_lib.IV(keyAndIV.iv);

      // Encrypt with AES/CBC/PKCS7
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'),
      );
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Construct the OpenSSL format bytes: "Salted__" (8 bytes) + salt (8 bytes) + ciphertext
      final saltedPrefix = utf8.encode("Salted__");
      final bytesWithSalt = Uint8List.fromList([
        ...saltedPrefix,
        ...salt,
        ...encrypted.bytes,
      ]);

      // Return as Base64 string
      return base64.encode(bytesWithSalt);
    } catch (e) {
      throw Exception("Encryption failed: $e");
    }
  }

  /// Replicates the EVP_BytesToKey MD5 key derivation
  static _KeyIV _deriveKeyAndIV(String passphrase, List<int> salt) {
    var password = utf8.encode(passphrase);
    List<int> concatenatedHashes = [];
    List<int> currentHash = [];
    bool enoughBytesForKey = false;

    // CryptoJS needs 32 bytes for the Key (AES-256) and 16 bytes for the IV
    while (!enoughBytesForKey) {
      var preHash = [...currentHash, ...password, ...salt];
      currentHash = md5.convert(preHash).bytes;
      concatenatedHashes.addAll(currentHash);
      if (concatenatedHashes.length >= 48) enoughBytesForKey = true;
    }

    var keyBytes = concatenatedHashes.sublist(0, 32);
    var ivBytes = concatenatedHashes.sublist(32, 48);
    return _KeyIV(Uint8List.fromList(keyBytes), Uint8List.fromList(ivBytes));
  }
}

class _KeyIV {
  final Uint8List key;
  final Uint8List iv;
  _KeyIV(this.key, this.iv);
}
