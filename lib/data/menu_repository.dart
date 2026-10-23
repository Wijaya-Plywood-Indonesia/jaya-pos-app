import 'dart:convert';

import '../core/api.dart';
import 'models.dart';
import 'session_store.dart';

class MenuResult {
  const MenuResult(this.data, {this.fromCache = false});

  final MenuData data;
  final bool fromCache;
}

class MenuRepository {
  MenuRepository(this.api, this.store);

  final Api api;
  final SessionStore store;

  /// Ambil menu dari server. Bila server tidak terjangkau, pakai salinan terakhir di perangkat.
  /// [skipNetwork] dipakai saat masuk lewat PIN offline (belum punya token).
  Future<MenuResult> load({bool skipNetwork = false}) async {
    if (skipNetwork) return _fromCache() ?? (throw _noCache());

    try {
      final json = await api.get('/menu');
      await store.saveMenu(jsonEncode(json));
      return MenuResult(MenuData.fromJson(json));
    } on ApiException catch (e) {
      // Token ditolak: bukan masalah koneksi, jangan pakai cache
      if (e.status == 401) rethrow;

      final cached = _fromCache();
      if (cached == null) rethrow;
      return cached;
    }
  }

  MenuResult? _fromCache() {
    final cached = store.menuCache;
    if (cached == null) return null;

    return MenuResult(
      MenuData.fromJson(jsonDecode(cached) as Map<String, dynamic>),
      fromCache: true,
    );
  }

  ApiException _noCache() {
    return ApiException('Menu belum tersimpan di perangkat. Sambungkan internet dulu.');
  }
}