import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openpgp/openpgp.dart';

class PgpService {
  final String _suffix;
  final _storage = const FlutterSecureStorage();

  PgpService({String suffix = ''}) : _suffix = suffix;

  String get _privateKeyKey => 'pgp_private_key$_suffix';
  String get _publicKeyKey => 'pgp_public_key$_suffix';

  // 1. Generate local keys
  Future<KeyPair> generateKeyPair(String name, String email) async {
    var keyOptions = KeyOptions()..rsaBits = 2048;
    var options = Options()
      ..name = name
      ..email = email
      ..keyOptions = keyOptions;
      
    final keyPair = await OpenPGP.generate(options: options);
    
    await savePrivateKeyLocal(keyPair.privateKey);
    await savePublicKeyLocal(keyPair.publicKey);
    return keyPair;
  }
  
  // 2. Encryption
  Future<String> encryptMessage(String plainText, String destPublicKey, String myPublicKey) async {
    // Encrypt for both public keys so sender and receiver can read it
    // The openpgp library allows passing multiple public keys
    final combinedKeys = destPublicKey + '\n' + myPublicKey;
    return await OpenPGP.encrypt(plainText, combinedKeys);
  }
  
  // 3. Decryption
  Future<String> decryptMessage(String cipherText) async {
    if (!cipherText.contains('BEGIN PGP MESSAGE')) {
      return cipherText; // Probably an old unencrypted message
    }
    
    final privateKey = await getPrivateKeyLocal();
    if (privateKey == null) {
      throw Exception("Clé privée introuvable localement");
    }
    
    return await OpenPGP.decrypt(cipherText, privateKey, '');
  }

  // 4. Secure Storage Management
  Future<void> savePrivateKeyLocal(String privateKey) async {
    await _storage.write(key: _privateKeyKey, value: privateKey);
  }
  
  Future<String?> getPrivateKeyLocal() async {
    return await _storage.read(key: _privateKeyKey);
  }

  Future<void> savePublicKeyLocal(String publicKey) async {
    await _storage.write(key: _publicKeyKey, value: publicKey);
  }

  Future<String?> getPublicKeyLocal() async {
    return await _storage.read(key: _publicKeyKey);
  }

  Future<void> clearLocalKeys() async {
    await _storage.delete(key: _privateKeyKey);
    await _storage.delete(key: _publicKeyKey);
  }

  // 5. Symmetric Encryption (For Server Backup)
  Future<String> encryptPrivateKeyWithPassword(String privateKey, String password) async {
    return await OpenPGP.encryptSymmetric(privateKey, password);
  }

  Future<String> decryptPrivateKeyWithPassword(String encryptedPrivateKey, String password) async {
    return await OpenPGP.decryptSymmetric(encryptedPrivateKey, password);
  }
}

final pgpServiceProvider = Provider<PgpService>((ref) {
  return PgpService();
});
