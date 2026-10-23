import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Penyimpanan di perangkat: token dan hash PIN di penyimpanan aman, data lain di preferences.
class SessionStore {
  SessionStore(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kBase = 'base_url';
  static const _kSlug = 'cafe_slug';
  static const _kCafe = 'cafe';
  static const _kUser = 'user';
  static const _kMenu = 'menu_cache';
  static const _kToken = 'token';
  static const _kOffline = 'offline_staff';
  static const _kFails = 'pin_fails';
  static const _kLockUntil = 'pin_lock_until';

  String? get baseUrl => _prefs.getString(_kBase);
  String? get slug => _prefs.getString(_kSlug);
  Cafe? get cafe => _decode(_kCafe, Cafe.fromJson);
  AppUser? get user => _decode(_kUser, AppUser.fromJson);
  String? get menuCache => _prefs.getString(_kMenu);

  Future<String?> readToken() => _secure.read(key: _kToken);

  T? _decode<T>(String key, T Function(Map<String, dynamic>) from) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return from(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActivation(String baseUrl, String slug, Cafe cafe) async {
    // Cafe berganti: buang data cafe sebelumnya
    if (this.slug != slug) {
      await _prefs.remove(_kMenu);
      await _secure.delete(key: _kOffline);
      await resetPinFails();
    }
    await _prefs.setString(_kBase, baseUrl);
    await _prefs.setString(_kSlug, slug);
    await _prefs.setString(_kCafe, jsonEncode(cafe.toJson()));
  }

  Future<void> saveLogin(String token, AppUser user, Cafe cafe) async {
    await _secure.write(key: _kToken, value: token);
    await _prefs.setString(_kUser, jsonEncode(user.toJson()));
    await _prefs.setString(_kCafe, jsonEncode(cafe.toJson()));
  }

  Future<void> saveMenu(String json) => _prefs.setString(_kMenu, json);

  // ---------- Login offline ----------

  Future<OfflineStaff?> readOfflineStaff() async {
    final raw = await _secure.read(key: _kOffline);
    if (raw == null) return null;
    try {
      return OfflineStaff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveOfflineStaff(OfflineStaff data) {
    return _secure.write(key: _kOffline, value: jsonEncode(data.toJson()));
  }

  int get pinFails => _prefs.getInt(_kFails) ?? 0;

  DateTime? get pinLockedUntil {
    final ms = _prefs.getInt(_kLockUntil);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> savePinFails(int count, {DateTime? lockUntil}) async {
    await _prefs.setInt(_kFails, count);
    if (lockUntil != null) {
      await _prefs.setInt(_kLockUntil, lockUntil.millisecondsSinceEpoch);
    }
  }

  Future<void> resetPinFails() async {
    await _prefs.remove(_kFails);
    await _prefs.remove(_kLockUntil);
  }

  // Keluar akun: token dibuang, tetapi hash PIN kasir tetap ada supaya bisa masuk offline
  Future<void> clearLogin() async {
    await _secure.delete(key: _kToken);
    await _prefs.remove(_kUser);
  }

  Future<void> clearAll() async {
    await clearLogin();
    await _secure.delete(key: _kOffline);
    await resetPinFails();
    await _prefs.remove(_kBase);
    await _prefs.remove(_kSlug);
    await _prefs.remove(_kCafe);
    await _prefs.remove(_kMenu);
  }
}