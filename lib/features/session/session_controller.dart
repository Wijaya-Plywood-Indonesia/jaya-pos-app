import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../data/models.dart';
import '../../data/session_store.dart';

enum Phase { activation, login, pos }

class SessionState {
  const SessionState({
    required this.phase,
    this.baseUrl,
    this.slug,
    this.cafe,
    this.user,
    this.token,
  });

  final Phase phase;
  final String? baseUrl;
  final String? slug;
  final Cafe? cafe;
  final AppUser? user;
  final String? token;
}

// Diisi di main.dart
final storeProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('storeProvider harus di-override di main.dart'),
);

final sessionProvider =
    AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends AsyncNotifier<SessionState> {
  SessionStore get _store => ref.read(storeProvider);

  @override
  Future<SessionState> build() async {
    final store = _store;
    final baseUrl = store.baseUrl;
    final slug = store.slug;

    if (baseUrl == null || slug == null) {
      return const SessionState(phase: Phase.activation);
    }

    final token = await store.readToken();
    final user = store.user;

    if (token != null && user != null) {
      return SessionState(
        phase: Phase.pos,
        baseUrl: baseUrl,
        slug: slug,
        cafe: store.cafe,
        user: user,
        token: token,
      );
    }

    return SessionState(
      phase: Phase.login,
      baseUrl: baseUrl,
      slug: slug,
      cafe: store.cafe,
    );
  }

  /// Aktivasi perangkat: memeriksa alamat server dan kode cafe. Melempar ApiException bila gagal.
  Future<void> activate(String baseUrl, String slug) async {
    final url = _normalizeUrl(baseUrl);
    final code = slug.trim().toLowerCase();

    final json = await Api(url).get('/cafes/$code/staff');
    final cafe = Cafe.fromJson(json['cafe'] as Map<String, dynamic>);

    await _store.saveActivation(url, code, cafe);

    state = AsyncData(
      SessionState(phase: Phase.login, baseUrl: url, slug: code, cafe: cafe),
    );
  }

  /// Login dengan PIN. Melempar ApiException bila PIN salah.
  Future<void> login(int staffId, String pin) async {
    final s = state.requireValue;

    final json = await Api(s.baseUrl!).post('/auth/pin-login', data: {
      'cafe': s.slug,
      'user_id': staffId,
      'pin': pin,
      'device_name': 'Aplikasi Kasir Android',
    });

    final token = json['token'] as String;
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    final cafe = Cafe.fromJson(json['cafe'] as Map<String, dynamic>);

    await _store.saveLogin(token, user, cafe);

    state = AsyncData(
      SessionState(
        phase: Phase.pos,
        baseUrl: s.baseUrl,
        slug: s.slug,
        cafe: cafe,
        user: user,
        token: token,
      ),
    );
  }

  Future<void> logout() async {
    final s = state.requireValue;

    if (s.token != null && s.baseUrl != null) {
      try {
        await Api(s.baseUrl!, token: s.token).post('/auth/logout');
      } catch (_) {
        // Tidak ada koneksi: tetap keluar di perangkat ini
      }
    }

    await expire();
  }

  /// Token tidak berlaku lagi (dicabut atau kedaluwarsa): kembali ke layar pilih akun.
  Future<void> expire() async {
    final s = state.requireValue;

    await _store.clearLogin();

    state = AsyncData(
      SessionState(
        phase: Phase.login,
        baseUrl: s.baseUrl,
        slug: s.slug,
        cafe: s.cafe,
      ),
    );
  }

  /// Ganti cafe: hapus aktivasi dan data cafe di perangkat.
  Future<void> resetActivation() async {
    await _store.clearAll();
    state = const AsyncData(SessionState(phase: Phase.activation));
  }

  String _normalizeUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }
}