import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/menu_repository.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../session/online_controller.dart';
import '../session/session_controller.dart';
import '../stock/stock_controller.dart';
import 'cart_controller.dart';
import 'cart_panel.dart';
import 'option_sheet.dart';
import 'pay_sheet.dart';
import 'pos_widgets.dart';
import 'receipt_sheet.dart';
import 'sync_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  late Future<MenuResult> _menu;
  final _search = TextEditingController();
  int? _categoryId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _menu = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<MenuResult> _load() async {
    final s = ref.read(sessionProvider).requireValue;
    final repo = MenuRepository(
      Api(s.baseUrl!, token: s.token),
      ref.read(storeProvider),
    );

    // Masuk lewat PIN offline: belum punya token, langsung pakai salinan menu
    final result = await repo.load(skipNetwork: s.offline);

    if (!s.offline) {
      ref.read(onlineProvider.notifier).report(!result.fromCache);
      if (!result.fromCache) {
        // Perbarui hash PIN kasir untuk login offline berikutnya
        ref.read(sessionProvider.notifier).refreshOfflineStaff();
        ref.read(sessionProvider.notifier).refreshCafe();

        // Stok dari server sudah memuat semua transaksi yang terkirim
        if (ref.read(syncProvider).pending == 0) {
          ref.read(soldLocalProvider.notifier).reset();
        }
      }
    }

    return result;
  }

  void _reload() {
    setState(() {
      _menu = _load();
    });
  }

  /// Muat ulang tanpa memutar layar: dipakai setelah transaksi terkirim atau stok dibeli,
  /// supaya label Habis dan Sisa ikut diperbarui.
  Future<void> _refreshSilently() async {
    try {
      final fresh = await _load();
      if (!mounted) return;

      setState(() {
        _menu = Future.value(fresh);
      });
    } catch (_) {
      // Gagal (misalnya offline): biarkan data yang sedang tampil
    }
  }

  // ---------------------------------------------------------------------------
  // Aksi kasir
  // ---------------------------------------------------------------------------
  /// [left] = sisa porsi menurut stok bahan (null = tanpa batas).
  Future<void> _openOptions(Product p, MenuData data, int? left) async {
    final groups = data.optionGroups.where((g) => p.optionGroupIds.contains(g.id)).toList();

    // Porsi yang sudah ada di keranjang ikut dihitung
    final inCart = ref
        .read(cartProvider)
        .lines
        .where((l) => l.productId == p.id)
        .fold<int>(0, (s, l) => s + l.qty);
    final remaining = left == null ? null : left - inCart;

    if (remaining != null && remaining <= 0) {
      showToast(context, 'Stok ${p.name} tidak cukup lagi', warn: true);
      return;
    }

    final line = await showOptionSheet(context, product: p, groups: groups, maxQty: remaining);

    if (line != null && mounted) {
      showToast(context, '${line.name} ×${line.qty} masuk pesanan');
    }
  }

  Future<void> _pay(MenuData data) async {
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      showToast(context, 'Pesanan masih kosong', warn: true);
      return;
    }

    final table = data.tables.where((t) => t.id == cart.tableId).firstOrNull;

    final order = await showAppSheet<PaidOrder>(context, (_) => PaySheet(table: table));
    if (order == null || !mounted) return;

    // Kurangi sisa porsi di tablet ini sampai stok terbaru dari server tiba
    ref.read(soldLocalProvider.notifier).add(order.items);

    ref.read(cartProvider.notifier).clear();
    await showReceiptSheet(context, order, isNew: true);
  }

  /// HP: pesanan aktif muncul dari bawah.
  void _openCartSheet(MenuData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: CartPanel(
            tables: data.tables,
            discounts: data.discounts,
            onClose: () => Navigator.pop(ctx),
            onPay: () {
              Navigator.pop(ctx);
              _pay(data);
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tampilan
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider).value;
    if (s == null) return const SizedBox.shrink();

    final sold = ref.watch(soldLocalProvider);

    // Transaksi terkirim ke server (stok di server berkurang) atau stok dibeli: segarkan menu
    ref.listen(syncProvider.select((x) => x.batchId), (prev, next) {
      if (prev != next) _refreshSilently();
    });
    ref.listen(stockRevisionProvider, (prev, next) => _refreshSilently());

    // Token offline berhasil didapat setelah internet kembali: muat menu terbaru
    ref.listen(sessionProvider, (prev, next) {
      final wasOffline = prev?.value?.offline ?? false;
      final isOffline = next.value?.offline ?? false;
      if (wasOffline && !isOffline && next.value?.phase == Phase.pos) _reload();
    });

    return FutureBuilder<MenuResult>(
      future: _menu,
      builder: (context, snap) {
        // Spinner hanya saat belum ada data sama sekali, bukan saat menyegarkan
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) return _errorView(snap.error);

        return _content(snap.data!, s.baseUrl!, sold);
      },
    );
  }

  Widget _errorView(Object? error) {
    final api = error is ApiException ? error : null;

    // Token dicabut (misalnya cafe dinonaktifkan): kembali ke layar pilih akun
    if (api?.status == 401) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionProvider.notifier).expire();
      });
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(api?.message ?? 'Gagal memuat menu.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reload, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Widget _content(MenuResult result, String baseUrl, Map<int, int> sold) {
    final data = result.data;

    return LayoutBuilder(
      builder: (context, c) {
        // Tablet: katalog di kiri, pesanan aktif menempel di kanan.
        // HP: katalog penuh, pesanan aktif dibuka dari tombol di bawah.
        final wide = c.maxWidth >= 600;
        final catalog = _catalog(result, baseUrl, wide, sold);

        if (wide) {
          return Row(
            children: [
              Expanded(child: catalog),
              SizedBox(
                width: 310,
                child: CartPanel(
                  tables: data.tables,
                  discounts: data.discounts,
                  onPay: () => _pay(data),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: catalog),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _CartBar(onTap: () => _openCartSheet(data)),
            ),
          ],
        );
      },
    );
  }

  Widget _catalog(MenuResult result, String baseUrl, bool wide, Map<int, int> sold) {
    final data = result.data;
    final accent = Theme.of(context).colorScheme.primary;
    final q = _query.trim().toLowerCase();

    final products = data.products
        .where((p) => _categoryId == null || p.categoryId == _categoryId)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return Column(
      children: [
        if (result.fromCache)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Mode offline: menu dari penyimpanan perangkat',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari menu',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.muted(context)),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.muted(context)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppColors.card(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: border(AppColors.line(context)),
                enabledBorder: border(AppColors.line(context)),
                focusedBorder: border(accent),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _chip('Semua', _categoryId == null, accent, () {
                setState(() => _categoryId = null);
              }),
              for (final c in data.categories)
                _chip(c.name, _categoryId == c.id, accent, () {
                  setState(() => _categoryId = c.id);
                }),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _menu;
              } catch (_) {}
            },
            child: products.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _query.isEmpty ? 'Belum ada menu' : 'Menu tidak ditemukan',
                            style: TextStyle(color: AppColors.muted(context)),
                          ),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // HP: sisakan ruang agar tombol "Lihat pesanan" tidak menutupi menu
                    padding: EdgeInsets.fromLTRB(16, 16, 16, wide ? 16 : 82),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];

                      // Sisa porsi dari server, dikurangi yang sudah terjual di tablet ini
                      final left = p.portions == null
                          ? null
                          : math.max(0, p.portions! - (sold[p.id] ?? 0));
                      final soldOut = !p.isAvailable || (left != null && left <= 0);

                      return _ProductCard(
                        product: p,
                        baseUrl: baseUrl,
                        left: left,
                        onTap: soldOut ? null : () => _openOptions(p, data, left),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, Color accent, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: accent,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : null,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Tombol "Lihat pesanan" di bawah katalog (hanya HP, hanya bila keranjang berisi).
class _CartBar extends ConsumerWidget {
  const _CartBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((c) => c.count));
    if (count == 0) return const SizedBox.shrink();

    final total = ref.watch(cartTotalsProvider).total;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent,
      elevation: 6,
      shadowColor: accent.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: 10,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  const Text(
                    'Lihat pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                rp(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.baseUrl,
    required this.onTap,
    this.left,
  });

  final Product product;
  final String baseUrl;

  /// Sisa porsi menurut stok bahan. null = tanpa batas.
  final int? left;

  /// null = menu habis, tidak bisa diketuk.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soldOut = !product.isAvailable || (left != null && left! <= 0);
    final low = !soldOut && left != null && left! <= 5;

    Widget placeholder() => Container(
          color: accent.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Text(
            initialOf(product.name),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.accentText(context),
            ),
          ),
        );

    final path = product.imagePath;

    return Opacity(
      opacity: soldOut ? 0.5 : 1,
      child: Material(
        color: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.line(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (path != null && path.isNotEmpty)
                      Image.network(
                        '$baseUrl$path',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder(),
                      )
                    else
                      placeholder(),
                    if (low)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Sisa $left',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (soldOut)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Habis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rp(product.price),
                      style: TextStyle(
                        color: AppColors.accentText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
