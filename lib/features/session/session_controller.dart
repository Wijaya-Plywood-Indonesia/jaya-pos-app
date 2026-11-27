import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../data/models.dart';
import '../../data/offline_pin.dart';
import '../../data/session_store.dart';

enum Phase { activation, login, pos }

/// PIN offline dikunci sementara karena terlalu banyak salah.
class PinLockedException extends RateLimitedException {
  PinLockedException(super.until);
}

class SessionState {
  const SessionState({
    required this.phase,
    this.baseUrl,
    this.slug,
    this.cafe,
    this.user,
    this.token,
    this.offline = false,
    this.notice,
  });

  final Phase phase;
  final String? baseUrl;
  final String? slug;
  final Cafe? cafe;
  final AppUser? user;
  final String? token;

  /// Masuk lewat PIN offline: belum punya token server.
  final bool offline;

  /// Pesan untuk layar login (misalnya PIN sudah diubah).
  final String? notice;
}

// Diisi di main.dart
final storeProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('storeProvider harus di-override di main.dart'),
);

final sessionProvider =
    AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends AsyncNotifier<SessionState> {
  static const _maxFails = 5;
  static const _lockFor = Duration(seconds: 60);

  // PIN kasir yang sedang masuk offline. Hanya di memori, tidak pernah disimpan.
  String? _memPin;
  bool _reconnecting = false;

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

  /// Aktivasi dengan kode sekali pakai dari panel admin (menu Perangkat).
  /// Server menukar kode dengan kode cafe, lalu alurnya sama dengan [activate].
  Future<void> activateWithCode(String baseUrl, String activationCode) async {
    final url = _normalizeUrl(baseUrl);
    final json = await Api(url).post('/devices/activate', data: {'code': activationCode.trim()});
    final slug = json['cafe_slug'] as String?;

    if (slug == null || slug.isEmpty) {
      throw ApiException('Respons server tidak dikenali.');
    }

    await activate(url, slug);
  }

  /// Login dengan PIN. Melempar ApiException bila gagal.
  ///
  /// Online dulu. Bila server tidak terjangkau dan akun ini kasir yang hash PIN-nya
  /// sudah tersimpan di perangkat, masuk lewat PIN offline. [preferOffline] melewati
  /// percobaan online (dipakai saat layar login sudah tahu sedang offline).
  Future<void> login(Staff staff, String pin, {bool preferOffline = false}) async {
    final s = state.requireValue;
    final saved = await _store.readOfflineStaff();
    final canOffline = staff.role == 'cashier' && (saved?.canLoginOffline(staff.id) ?? false);

    if (preferOffline) {
      if (!canOffline) throw ApiException(_offlineRefusal(staff));
      return _loginOffline(s, staff, saved!, pin);
    }

    try {
      await _loginOnline(s, staff.id, pin);
    } on ApiException catch (e) {
      final unreachable = e.status == null || e.status! >= 500;
      if (!unreachable) rethrow;
      if (!canOffline) throw ApiException(_offlineRefusal(staff));
      await _loginOffline(s, staff, saved!, pin);
    }
  }

  String _offlineRefusal(Staff staff) {
    return staff.role == 'cashier'
        ? 'Tidak ada internet, dan akun ini belum tersimpan di perangkat. Sambungkan internet sekali dulu.'
        : 'Owner dan manajer butuh internet untuk masuk.';
  }

  Future<void> _loginOnline(SessionState s, int staffId, String pin) async {
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
    _memPin = null;

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

    // Perbarui salinan staf untuk login offline berikutnya
    unawaited(refreshOfflineStaff());
  }

  Future<void> _loginOffline(
    SessionState s,
    Staff staff,
    OfflineStaff saved,
    String pin,
  ) async {
    final now = DateTime.now();
    final lock = _store.pinLockedUntil;

        if (lock != null && lock.isAfter(now)) throw PinLockedException(lock);

    final ok = await verifyPinAsync(pin, saved.pins[staff.id]!);

    if (!ok) {
      final fails = _store.pinFails + 1;
            if (fails >= _maxFails) {
        final until = now.add(_lockFor);
        await _store.savePinFails(0, lockUntil: until);
        throw PinLockedException(until);
      }
      await _store.savePinFails(fails);
      throw ApiException('PIN salah.');
    }

    await _store.resetPinFails();
    _memPin = pin;

    state = AsyncData(
      SessionState(
        phase: Phase.pos,
        baseUrl: s.baseUrl,
        slug: s.slug,
        cafe: s.cafe,
        user: AppUser(
          id: staff.id,
          name: staff.name,
          role: staff.role,
          outletId: staff.outletId,
        ),
        offline: true,
      ),
    );
  }

  /// Dipanggil saat internet kembali. Bila masuk lewat PIN offline, ambil token diam-diam.
  Future<void> goOnline() async {
    final s = state.value;
    if (s == null || !s.offline || s.user == null || _memPin == null || _reconnecting) {
      return;
    }

    _reconnecting = true;
    try {
      await _loginOnline(s, s.user!.id, _memPin!);
    } on ApiException catch (e) {
      if (e.status == 422) {
        // PIN sudah diubah (atau akun dinonaktifkan) di panel
        await expire(notice: 'PIN atau akun Anda berubah. Silakan masuk lagi.');
      }
      // Gangguan lain: tetap offline, dicoba lagi pada pengecekan berikutnya
    } finally {
      _reconnecting = false;
    }
  }

  /// Unduh daftar staf + hash PIN kasir untuk login offline. Gagal diam-diam.
  Future<void> refreshOfflineStaff() async {
    final s = state.value;
    if (s == null || s.token == null || s.baseUrl == null) return;

    try {
      final json = await Api(s.baseUrl!, token: s.token).get('/auth/offline-staff');
      await _store.saveOfflineStaff(OfflineStaff.fromJson(json));
    } catch (_) {
      // Tidak masalah: pakai salinan lama
    }
  }
    /// Ambil pengaturan cafe terbaru (pajak, service, pembulatan, struk, warna tema),
  /// supaya perubahan di panel web berlaku tanpa kasir harus login ulang.
  Future<void> refreshCafe() async {
    final s = state.value;
    if (s == null || s.token == null || s.baseUrl == null) return;

    try {
      final json = await Api(s.baseUrl!, token: s.token).get('/me');
      final raw = json['cafe'];
      if (raw is! Map<String, dynamic>) return;

      final cafe = Cafe.fromJson(raw);
      await _store.saveCafe(cafe);

      state = AsyncData(
        SessionState(
          phase: s.phase,
          baseUrl: s.baseUrl,
          slug: s.slug,
          cafe: cafe,
          user: s.user,
          token: s.token,
          offline: s.offline,
          notice: s.notice,
        ),
      );
    } catch (_) {
      // Tidak masalah: pakai pengaturan yang tersimpan
    }
  }

  Future<OfflineStaff?> offlineStaff() => _store.readOfflineStaff();

  /// Apakah akun ini bisa masuk lagi tanpa internet setelah keluar?
  Future<bool> canLoginOffline(AppUser user) async {
    if (user.role != 'cashier') return false;
    final saved = await _store.readOfflineStaff();
    return saved?.canLoginOffline(user.id) ?? false;
  }

    Future<void> logout({String? notice}) async {
    final s = state.requireValue;

    if (s.token != null && s.baseUrl != null) {
      try {
        await Api(s.baseUrl!, token: s.token).post('/auth/logout');
      } catch (_) {
        // Tidak ada koneksi: tetap keluar di perangkat ini
      }
    }

    await expire(notice: notice);
  }

  /// Token tidak berlaku lagi (dicabut atau kedaluwarsa): kembali ke layar pilih akun.
  Future<void> expire({String? notice}) async {
    final s = state.requireValue;

    _memPin = null;
    await _store.clearLogin();

    state = AsyncData(
      SessionState(
        phase: Phase.login,
        baseUrl: s.baseUrl,
        slug: s.slug,
        cafe: s.cafe,
        notice: notice,
      ),
    );
  }

  /// Ganti cafe: hapus aktivasi dan data cafe di perangkat.
  Future<void> resetActivation() async {
    _memPin = null;
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