import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../session/session_controller.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  // Alamat server bawaan. Untuk rilis, build dengan:
  //   flutter build apk --dart-define=JAYA_SERVER_URL=https://api.domainmu.com
  // Tanpa itu, dipakai 10.0.2.2 (alamat komputer dari dalam emulator Android).
  static const _defaultServer = String.fromEnvironment(
    'JAYA_SERVER_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  final _url = TextEditingController(text: _defaultServer);
  final _code = TextEditingController();
  final _slug = TextEditingController();
  bool _busy = false;
  bool _advanced = false;
  bool _useCafeCode = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    _slug.dispose();
    super.dispose();
  }

  /// Buka halaman pendaftaran di browser, memakai alamat server yang sedang diisi.
  Future<void> _openSignup() async {
    var base = _url.text.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    final ok = await launchUrl(Uri.parse('$base/daftar'), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Tidak bisa membuka browser. Buka $base/daftar secara manual.');
    }
  }

  Future<void> _submit() async {
    final empty = _useCafeCode ? _slug.text.trim().isEmpty : _code.text.trim().isEmpty;
    if (empty) {
      setState(() => _error = _useCafeCode ? 'Masukkan kode cafe.' : 'Masukkan kode aktivasi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = ref.read(sessionProvider.notifier);
      if (_useCafeCode) {
        await session.activate(_url.text, _slug.text);
      } else {
        await session.activateWithCode(_url.text, _code.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MawraLogo(size: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aktifkan perangkat',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _useCafeCode
                        ? 'Masukkan alamat server dan kode cafe dari owner.'
                        : 'Masukkan kode aktivasi dari owner (menu Perangkat di panel admin). Langkah ini hanya sekali.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted(context)),
                  ),
                  const SizedBox(height: 24),
                  if (_useCafeCode) ...[
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: _decoration('Alamat server'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _slug,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: _decoration('Kode cafe', hint: 'contoh: jaya-cafe'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _code,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                      decoration: _decoration('Kode aktivasi', hint: 'XXXX-XXXX'),
                    ),
                    if (_advanced) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: _decoration('Alamat server'),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Aktifkan'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_useCafeCode)
                        TextButton(
                          onPressed: () => setState(() => _advanced = !_advanced),
                          child: Text(_advanced ? 'Sembunyikan alamat server' : 'Ubah alamat server'),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          _useCafeCode = !_useCafeCode;
                          _error = null;
                        }),
                        child: Text(_useCafeCode ? 'Pakai kode aktivasi' : 'Pakai kode cafe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _openSignup,
                      child: const Text('Belum punya cafe? Daftar gratis'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}