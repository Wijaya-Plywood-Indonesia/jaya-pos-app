import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_controller.dart';
import 'session_controller.dart';

/// Keluar akun. Bila sedang offline dan akun ini tidak bisa masuk lagi tanpa internet,
/// minta konfirmasi dulu.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final user = ref.read(sessionProvider).value?.user;
  if (user == null) return;

  final online = ref.read(onlineProvider);
  final notifier = ref.read(sessionProvider.notifier);

  if (!online) {
    final canReturn = await notifier.canLoginOffline(user);
    if (!canReturn) {
      if (!context.mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Anda sedang offline'),
          content: const Text(
            'Setelah keluar, akun ini tidak bisa masuk lagi sampai internet kembali. Tetap keluar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap keluar'),
            ),
          ],
        ),
      );

      if (ok != true) return;
    }
  }

  await notifier.logout();
}