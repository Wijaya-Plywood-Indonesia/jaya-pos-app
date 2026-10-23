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
  Future<MenuResult> load() async {
    try {
      final json = await api.get('/menu');
      await store.saveMenu(jsonEncode(json));
      return MenuResult(MenuData.fromJson(json));
    } on ApiException catch (e) {
      // Token ditolak: bukan masalah koneksi, jangan pakai cache
      if (e.status == 401) rethrow;

      final cached = store.menuCache;
      if (cached == null) rethrow;

      return MenuResult(
        MenuData.fromJson(jsonDecode(cached) as Map<String, dynamic>),
        fromCache: true,
      );
    }
  }
}