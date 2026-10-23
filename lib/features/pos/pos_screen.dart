import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/menu_repository.dart';
import '../../data/models.dart';
import '../session/connection_chip.dart';
import '../session/logout_flow.dart';
import '../session/online_controller.dart';
import '../session/session_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  late Future<MenuResult> _menu;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _menu = _load();
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
      }
    }

    return result;
  }

  void _reload() {
    setState(() {
      _menu = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider).value;
    if (s == null) return const SizedBox.shrink();

    // Token offline berhasil didapat setelah internet kembali: muat menu terbaru
    ref.listen(sessionProvider, (prev, next) {
      final wasOffline = prev?.value?.offline ?? false;
      final isOffline = next.value?.offline ?? false;
      if (wasOffline && !isOffline && next.value?.phase == Phase.pos) _reload();
    });

    final cafeName = s.cafe?.name ?? 'Jaya POS';
    final user = s.user;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.card(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            BrandMark(letter: initialOf(cafeName), size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                cafeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          const ConnectionChip(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Muat ulang menu',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          if (user != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'logout') confirmLogout(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('${user.name} · ${roleLabel(user.role)}'),
                ),
                const PopupMenuItem<String>(value: 'logout', child: Text('Keluar')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Avatar(name: user.name, owner: user.role == 'owner', size: 34),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.line(context)),
        ),
      ),
      body: FutureBuilder<MenuResult>(
        future: _menu,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) return _errorView(snap.error);

          return _content(snap.data!, s.baseUrl!);
        },
      ),
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

  Widget _content(MenuResult result, String baseUrl) {
    final data = result.data;
    final accent = Theme.of(context).colorScheme.primary;

    final products = data.products
        .where((p) => _categoryId == null || p.categoryId == _categoryId)
        .toList();

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
                            'Belum ada menu',
                            style: TextStyle(color: AppColors.muted(context)),
                          ),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) =>
                        _ProductCard(product: products[i], baseUrl: baseUrl),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.baseUrl});

  final Product product;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    Widget placeholder() => Container(
          color: accent.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Text(
            initialOf(product.name),
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: accent),
          ),
        );

    final path = product.imagePath;

    return Opacity(
      opacity: product.isAvailable ? 1 : 0.5,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line(context)),
        ),
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
                  if (!product.isAvailable)
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
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}