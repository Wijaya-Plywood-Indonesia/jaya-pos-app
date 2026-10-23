import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../session/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _pinLength = 4;

  late Future<List<Staff>> _staff;
  Staff? _selected;
  String _pin = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _staff = _loadStaff();
  }

  Future<List<Staff>> _loadStaff() async {
    final s = ref.read(sessionProvider).requireValue;
    final json = await Api(s.baseUrl!).get('/cafes/${s.slug}/staff');
    final list = (json['staff'] as List?) ?? const [];
    return list.map((e) => Staff.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _reloadStaff() {
    setState(() {
      _staff = _loadStaff();
    });
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= _pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
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
      await ref.read(sessionProvider.notifier).login(staff.id, _pin);
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

  // ---------- Tahap 1: pilih akun ----------
  Widget _staffStage(String cafeName) {
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
        FutureBuilder<List<Staff>>(
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

            final staff = snap.data ?? const <Staff>[];
            if (staff.isEmpty) {
              return Text(
                'Belum ada akun. Minta owner menambahkan staf di panel web.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted(context)),
              );
            }

            return Column(
              children: [for (final s in staff) _staffTile(s)],
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

  Widget _staffTile(Staff s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _selected = s;
          _pin = '';
          _error = null;
        }),
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
                      roleLabel(s.role),
                      style: TextStyle(color: AppColors.muted(context), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.muted(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Tahap 2: masukkan PIN ----------
  Widget _pinStage() {
    final staff = _selected!;
    final accent = Theme.of(context).colorScheme.primary;

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
            child: _error == null
                ? null
                : Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        _PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
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