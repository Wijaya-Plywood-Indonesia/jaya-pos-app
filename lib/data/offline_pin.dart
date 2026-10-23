import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

/// Laravel membuat hash berawalan $2y$, pustaka bcrypt Dart memakai $2a$.
/// Isinya sama persis, jadi cukup ganti awalannya.
String normalizeHash(String hash) {
  return hash.startsWith(r'$2y$') ? r'$2a$' + hash.substring(4) : hash;
}

bool verifyPin(String pin, String hash) {
  try {
    return BCrypt.checkpw(pin, normalizeHash(hash));
  } catch (_) {
    return false;
  }
}

/// bcrypt itu sengaja lambat, jadi dijalankan di isolate agar layar tidak macet.
Future<bool> verifyPinAsync(String pin, String hash) {
  return compute(_verify, <String>[pin, hash]);
}

bool _verify(List<String> args) => verifyPin(args[0], args[1]);