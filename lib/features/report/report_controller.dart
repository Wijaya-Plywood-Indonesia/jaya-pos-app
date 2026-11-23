import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../data/report_models.dart';
import '../pos/sync_controller.dart';
import '../session/session_controller.dart';

/// Ringkasan penjualan per periode (day, week, month). Dimuat ulang setiap kali
/// transaksi baru terkirim ke server.
final reportProvider = FutureProvider.family<ReportData, String>((ref, period) async {
  ref.watch(syncProvider.select((s) => s.batchId));

  final s = ref.watch(sessionProvider).value;
  final baseUrl = s?.baseUrl;
  final token = s?.token;

  if (baseUrl == null || token == null) {
    throw ApiException('Laporan butuh internet. Masuk lagi saat online.');
  }

  final json = await Api(baseUrl, token: token).get('/reports/summary?period=$period');

  return ReportData.fromJson(json);
});
