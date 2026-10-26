import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_controller.dart';
import 'session_controller.dart';

/// true bila boleh lanjut keluar: sedang online, atau akun ini bisa masuk lagi tanpa
/// internet, atau pengguna menyetujui peringatan.
Future<bool> confirmLeave(BuildContext context, WidgetRef ref) async {
  final user = ref.read(sessionProvider).value?.user;
  if (user == null) return false;

  if (ref.read(onlineProvider)) return true;

  final canReturn = await ref.read(sessionProvider.notifier).canLoginOffline(user);
  if (canReturn) return true;
  if (!context.mounted) return false;

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

  return ok == true;
}

/// Keluar akun, dengan peringatan bila sedang offline.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  if (!await confirmLeave(context, ref)) return;

  await ref.read(sessionProvider.notifier).logout();
}