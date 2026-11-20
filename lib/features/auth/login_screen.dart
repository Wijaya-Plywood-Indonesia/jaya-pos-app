import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../session/online_controller.dart';
import '../session/session_controller.dart';

class _StaffResult {
  const _StaffResult(this.staff, {required this.offline, required this.offlineIds});

  final List<Staff> staff;

  /// true = daftar diambil dari penyimpanan perangkat karena server tidak terjangkau
  final bool offline;

  /// id staf yang bisa masuk tanpa internet
  final Set<int> offlineIds;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _pinLength = 4;

  late Future<_StaffResult> _staff;
  Staff? _selected;
  String _pin = '';
  bool _busy = false;
  bool _offlineList = false;
  String? _error;

  // Hitung mundur saat PIN offline dikunci
  Timer? _lockTimer;
  DateTime? _lockUntil;
  int _lockSecs = 0;

  @override
  void initState() {
    super.initState();
    _staff = _loadStaff();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  /// Hitung sisa detik kunci dan jalankan penghitung per detik sampai habis.
  void _tick() {
    final until = _lockUntil;
    final ms = until == null ? 0 : until.difference(DateTime.now()).inMilliseconds;

    if (ms <= 0) {
      _lockTimer?.cancel();
      _lockTimer = null;
      if (mounted) {
        setState(() {
          _lockUntil = null;
          _lockSecs = 0;
        });
      }
      return;
    }

    if (mounted) setState(() => _lockSecs = (ms / 1000).ceil());
    _lockTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<_StaffResult> _loadStaff() async {
    final s = ref.read(sessionProvider).requireValue;
    final notifier = ref.read(sessionProvider.notifier);

    try {
      final json = await Api(s.baseUrl!).get('/cafes/${s.slug}/staff');
      final list = ((json['staff'] as List?) ?? const [])
          .map((e) => Staff.fromJson(e as Map<String, dynamic>))
          .toList();
      final saved = await notifier.offlineStaff();

      _offlineList = false;
      ref.read(onlineProvider.notifier).report(true);
      return _StaffResult(list, offline: false, offlineIds: saved?.pins.keys.toSet() ?? {});
    } on ApiException catch (e) {
      final unreachable = e.status == null || e.status! >= 500;
      final saved = await notifier.offlineStaff();
      if (!unreachable || saved == null) rethrow;

      _offlineList = true;
      ref.read(onlineProvider.notifier).report(false);
      return _StaffResult(saved.staff, offline: true, offlineIds: saved.pins.keys.toSet());
    }
  }

  void _reloadStaff() {
    setState(() {
      _staff = _loadStaff();
    });
  }

  void _onDigit(String d) {
    if (_busy || _lockSecs > 0 || _pin.length >= _pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_busy || _lockSecs > 0 || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final staff = _selected;
    if (staff == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(sessionProvider.notifier)
          .login(staff, _pin, preferOffline: _offlineList);
        } on RateLimitedException catch (e) {
      if (mounted) {
        setState(() {
          _pin = '';
          _error = null;
          _lockUntil = e.until;
        });
        _tick();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Internet kembali saat di layar pilih akun: muat ulang daftar dari server
    ref.listen<bool>(onlineProvider, (prev, next) {
      if (prev == false && next == true && _selected == null) _reloadStaff();
    });

    final cafe = ref.watch(sessionProvider).value?.cafe;
    final cafeName = cafe?.name ?? 'Jaya POS';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _selected == null
                  ? _staffStage(cafeName)
                  : _pinStage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Tahap 1: pilih akun ----------
  Widget _staffStage(String cafeName) {
    final notice = ref.watch(sessionProvider).value?.notice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: BrandMark(letter: initialOf(cafeName), size: 56)),
        const SizedBox(height: 16),
        Text(
          cafeName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Pilih akun untuk masuk',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted(context)),
        ),
        const SizedBox(height: 20),
        if (notice != null) _banner(notice, Icons.info_outline),
        FutureBuilder<_StaffResult>(
          future: _staff,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              final msg = snap.error is ApiException
                  ? (snap.error as ApiException).message
                  : 'Gagal memuat daftar akun.';
              return Column(
                children: [
                  Text(msg, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reloadStaff, child: const Text('Coba lagi')),
                ],
              );
            }

            final result = snap.data!;
            final staff = result.staff;

            if (staff.isEmpty) {
              return Text(
                'Belum ada akun. Minta owner menambahkan staf di panel web.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted(context)),
              );
            }

            return Column(
              children: [
                if (result.offline)
                  _banner(
                    'Mode offline. Hanya kasir yang bisa masuk.',
                    Icons.cloud_off_outlined,
                  ),
                for (final s in staff)
                  _staffTile(
                    s,
                    enabled: !result.offline || result.offlineIds.contains(s.id),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ref.read(sessionProvider.notifier).resetActivation(),
          child: const Text('Ganti cafe'),
        ),
      ],
    );
  }

  Widget _staffTile(Staff s, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!enabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    s.role == 'cashier'
                        ? 'Akun kasir ini belum tersimpan di perangkat. Sambungkan internet sekali.'
                        : 'Owner dan manajer butuh internet untuk masuk.',
                  ),
                ),
              );
              return;
            }
            setState(() {
              _selected = s;
              _pin = '';
              _error = null;
              // Kunci PIN offline masih berlaku? Tampilkan hitung mundurnya langsung
              _lockUntil = _offlineList ? ref.read(storeProvider).pinLockedUntil : null;
            });
            _tick();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line(context)),
            ),
            child: Row(
              children: [
                Avatar(name: s.name, owner: s.role == 'owner', size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        enabled ? roleLabel(s.role) : '${roleLabel(s.role)} · butuh internet',
                        style: TextStyle(color: AppColors.muted(context), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.chevron_right : Icons.lock_outline,
                  color: AppColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Tahap 2: masukkan PIN ----------
  Widget _pinStage() {
    final staff = _selected!;
    final accent = AppColors.accentText(context);
    final locked = _lockSecs > 0;
    final message = locked
        ? 'Terlalu banyak percobaan. Coba lagi dalam $_lockSecs detik.'
        : _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Avatar(name: staff.name, owner: staff.role == 'owner', size: 64)),
        const SizedBox(height: 12),
        Text(
          staff.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Masukkan PIN $_pinLength angka',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted(context)),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (i) {
            final filled = i < _pin.length;
            return Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? accent : Colors.transparent,
                border: Border.all(
                  color: filled ? accent : AppColors.muted(context),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: message == null
                ? null
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        // Selama dikunci, tombol angka dipudarkan dan tidak bisa ditekan
        Opacity(
          opacity: locked ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: locked,
            child: _PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _selected = null;
                    _pin = '';
                    _error = null;
                  }),
          child: const Text('Ganti akun'),
        ),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row) _PadKey(label: d, onTap: () => onDigit(d)),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _PadKey(label: '0', onTap: () => onDigit('0')),
            _PadKey(icon: Icons.backspace_outlined, onTap: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 76,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line(context)),
          ),
          child: icon != null
              ? Icon(icon, size: 22)
              : Text(
                  label!,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}