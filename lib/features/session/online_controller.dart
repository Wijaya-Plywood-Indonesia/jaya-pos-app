import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'session_controller.dart';

/// true = server terjangkau. Dicek tiap 15 detik dan setiap ada hasil panggilan API.
final onlineProvider = NotifierProvider<OnlineController, bool>(OnlineController.new);

class OnlineController extends Notifier<bool> {
  Timer? _timer;
  bool _checking = false;

  @override
  bool build() {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(check);
    return true;
  }

  Future<void> check() async {
    if (_checking) return;

    final s = ref.read(sessionProvider).value;
    if (s?.baseUrl == null || s?.slug == null) return;

    _checking = true;
    try {
      await Api(s!.baseUrl!).get('/cafes/${s.slug}/staff');
      report(true);
    } on ApiException catch (e) {
      // Server menjawab (selain gangguan 5xx) berarti terjangkau
      report(e.status != null && e.status! < 500);
    } catch (_) {
      report(false);
    } finally {
      _checking = false;
    }
  }

  /// Dilaporkan juga oleh bagian lain yang baru saja memanggil server.
  void report(bool online) {
    final wasOffline = !state;
    if (state != online) state = online;

    if (wasOffline && online) _onBackOnline();
  }

  Future<void> _onBackOnline() async {
    final session = ref.read(sessionProvider.notifier);
    await session.goOnline();
    await session.refreshOfflineStaff();
  }
}