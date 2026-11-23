import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/report_models.dart';
import '../pos/pos_widgets.dart';
import 'report_controller.dart';

/// Laporan untuk owner: omset, laba kotor, metode bayar, grafik, dan menu terlaris.
/// Data dari server, jadi mencakup semua tablet dan butuh internet.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _periods = [('day', 'Hari ini'), ('week', '7 hari'), ('month', 'Bulan ini')];

  String _period = 'day';

  Future<void> _refresh() async {
    ref.invalidate(reportProvider(_period));

    try {
      await ref.read(reportProvider(_period).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider(_period));
    final accent = Theme.of(context).colorScheme.primary;
    final data = report.value;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, c) {
          const pad = 12.0;
          const gap = 10.0;
          final twoCols = c.maxWidth >= 700;
          final colWidth = twoCols ? (c.maxWidth - pad * 2 - gap) / 2 : c.maxWidth - pad * 2;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(pad),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    for (final (key, label) in _periods)
                      ChoiceChip(
                        label: Text(label),
                        selected: _period == key,
                        showCheckmark: false,
                        selectedColor: accent,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _period == key ? Colors.white : null,
                        ),
                        onSelected: (_) => setState(() => _period = key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (data == null && report.hasError)
                _ErrorBox(
                  message: report.error is ApiException
                      ? (report.error as ApiException).message
                      : 'Laporan gagal dimuat.',
                  onRetry: _refresh,
                )
              else if (data == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SubText('${data.label} · ${data.rangeText}'),
                const SizedBox(height: 8),
                _Kpis(data: data, width: c.maxWidth - pad * 2),
                const SizedBox(height: gap),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(width: colWidth, child: _ProfitCard(data: data)),
                    SizedBox(width: colWidth, child: _PaymentsCard(data: data)),
                    SizedBox(width: colWidth, child: _ChartCard(data: data)),
                    SizedBox(width: colWidth, child: _TopCard(data: data)),
                  ],
                ),
                const SizedBox(height: gap),
                const NoteBox(
                  'Unduh Excel dan cetak PDF dari panel web: menu Laporan. Tarik layar ke bawah untuk memperbarui angka.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        spacing: 12,
        children: [
          Text(message, textAlign: TextAlign.center),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          child,
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.data, required this.width});

  final ReportData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final green = isDarkMode(context) ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    final cols = width >= 700 ? 4 : 2;
    const gap = 10.0;
    final w = (width - gap * (cols - 1)) / cols;

    Widget kpi(String label, String value, String hint, {Color? color}) {
      return SizedBox(
        width: w,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              Text(hint, style: TextStyle(fontSize: 11.5, color: AppColors.muted(context))),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        kpi('Omset bersih', rp(data.salesNet), 'Setelah diskon, sebelum pajak'),
        kpi('Laba kotor', rp(data.grossProfit), 'Margin ${data.margin}%', color: green),
        kpi('Transaksi', '${data.transactions}', 'Yang sudah dibayar'),
        kpi('Rata-rata per transaksi', rp(data.average), 'Sebelum pajak'),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color, this.bold = false});

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      color: color ?? (bold ? null : AppColors.muted(context)),
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 10,
        children: [
          Flexible(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final green = dark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    final amber = dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    final red = dark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);

    return _Card(
      title: 'Laba rugi · ${data.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Line('Penjualan kotor', rp(data.salesGross)),
          _Line('Diskon diberikan', '− ${rp(data.discount)}', color: amber),
          _Line('Omset bersih', rp(data.salesNet)),
          _Line('HPP bahan terpakai', '− ${rp(data.hpp)}', color: red),
          const DashedDivider(margin: EdgeInsets.symmetric(vertical: 6)),
          _Line('Laba kotor', rp(data.grossProfit), color: green, bold: true),
          const SizedBox(height: 8),
          SubText('Arus kas dan titipan, dicatat terpisah'),
          _Line('Belanja restock stok', '− ${rp(data.expenses)}', color: amber),
          _Line('Layanan (service) terkumpul', rp(data.service)),
          _Line('Pajak terkumpul (titipan)', rp(data.tax)),
          const SizedBox(height: 4),
          const SubText('HPP hanya menghitung menu yang sudah punya resep.'),
        ],
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.data});

  final ReportData data;

  static const _colors = {
    'cash': Color(0xFFDC2626),
    'qris': Color(0xFF2563EB),
    'card': Color(0xFF6B7280),
    'transfer': Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    if (data.payments.isEmpty) {
      return _Card(
        title: 'Uang diterima per metode bayar',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Belum ada pembayaran',
              style: TextStyle(color: AppColors.muted(context)),
            ),
          ),
        ),
      );
    }

    return _Card(
      title: 'Uang diterima per metode bayar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final p in data.payments)
                    Expanded(
                      flex: math.max(1, p.amount),
                      child: ColoredBox(color: _colors[p.method] ?? const Color(0xFF9CA3AF)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final p in data.payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    spacing: 7,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colors[p.method] ?? const Color(0xFF9CA3AF),
                        ),
                      ),
                      Text(p.label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  Text(
                    '${rp(p.amount)} · ${p.pct}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const SubText('Termasuk pajak, layanan, dan pembulatan.'),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final title = data.bucket == 'hour' ? 'Omset bersih per jam' : 'Omset bersih per hari';
    final empty = data.series.isEmpty || data.series.every((p) => p.value == 0);

    if (empty) {
      return _Card(
        title: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Belum ada penjualan',
              style: TextStyle(color: AppColors.muted(context)),
            ),
          ),
        ),
      );
    }

    final maxValue = data.series.map((p) => p.value).reduce(math.max);
    final labelEvery = math.max(1, (data.series.length / 10).ceil());
    final accent = Theme.of(context).colorScheme.primary;
    final showValues = data.series.length <= 8;
    const barArea = 110.0;

    return _Card(
      title: title,
      child: SizedBox(
        height: barArea + 38,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in data.series.asMap().entries)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showValues && e.value.value > 0)
                      Text(
                        _short(e.value.value),
                        style: TextStyle(fontSize: 9.5, color: AppColors.muted(context)),
                      ),
                    const SizedBox(height: 2),
                    Container(
                      height: e.value.value == 0 ? 0.0 : math.max(3.0, e.value.value / maxValue * barArea),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: e.value.value == maxValue ? 1 : 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: e.key % labelEvery == 0
                          ? Text(
                              e.value.label,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: TextStyle(fontSize: 10, color: AppColors.muted(context)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 1.250.000 -> "1,3 jt", 45.000 -> "45 rb"
  static String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
    if (n >= 1000) return '${(n / 1000).round()} rb';

    return '$n';
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (data.top.isEmpty) {
      return _Card(
        title: 'Menu terlaris',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Belum ada penjualan',
              style: TextStyle(color: AppColors.muted(context)),
            ),
          ),
        ),
      );
    }

    return _Card(
      title: 'Menu terlaris',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in data.top.take(5).toList().asMap().entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                border: e.key == 0 ? null : Border(top: BorderSide(color: softLine(context))),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentText(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${e.value.qty} porsi',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        rp(e.value.revenue),
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
