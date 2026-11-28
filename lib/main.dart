import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/theme_mode.dart';
import 'data/local_db.dart';
import 'data/session_store.dart';
import 'features/auth/activation_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/session/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final store = SessionStore(prefs, const FlutterSecureStorage());
  final db = await LocalDb.open();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        storeProvider.overrideWithValue(store),
        localDbProvider.overrideWithValue(db),
      ],
      child: const JayaApp(),
    ),
  );
}

class JayaApp extends ConsumerWidget {
  const JayaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    // Warna aplikasi mengikuti "Warna tema" cafe setelah aktivasi
    final accent = AppColors.parse(session?.cafe?.themeColor);

    return MaterialApp(
      title: 'Mawra POS',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      theme: AppColors.theme(Brightness.light, accent),
      darkTheme: AppColors.theme(Brightness.dark, accent),
      home: const Gate(),
    );
  }
}

// Menentukan layar berdasarkan status: belum aktivasi, belum login, atau sudah login
class Gate extends ConsumerWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Gagal memuat: $e'))),
      data: (s) => switch (s.phase) {
        Phase.activation => const ActivationScreen(),
        Phase.login => const LoginScreen(),
        Phase.pos => const HomeShell(),
      },
    );
  }
}