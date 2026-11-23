import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../pos/pos_widgets.dart';
import '../session/session_controller.dart';
import 'restock_sheet.dart';
import 'stock_controller.dart';

/// Stok bahan baku. Owner dan manajer juga melihat resep, HPP, dan bisa membeli stok.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _view = 'inv';

  Future<void> _refresh() async {
    ref.invalidate(menuDataProvider);

    try {
      await ref.read(menuDataProvider.future);
    } catch (_) {}
  }

  Future<void> _restock(List<IngredientInfo> items, {int? selectedId}) async {
    final done = await showRestockSheet(context, ingredients: items, selectedId: selectedId);

    if (done == true && mounted) {
      showToast(context, 'Stok bertambah dan pembelian dicatat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuDataProvider);
    final role = ref.watch(sessionProvider.select((s) => s.value?.user?.role));
    final isManager = role == 'owner' || role == 'manager';
    final accent = Theme.of(context).colorScheme.primary;

    final result = menu.value;

    if (result == null) {
      if (menu.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const Text('Stok gagal dimuat.'),
              OutlinedButton(onPressed: _refresh, child: const Text('Coba lagi')),
            ],
          ),
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    final data = result.data;
    final view = (_view == 'rec' && isManager) ? 'rec' : 'inv';

    return LayoutBuilder(
      builder: (context, c) {
        const pad = 12.0;
        const gap = 10.0;
        final twoCols = c.maxWidth >= 700;
        final cardWidth = twoCols ? (c.maxWidth - pad * 2 - gap) / 2 : c.maxWidth - pad * 2;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(pad),
            children: [
              if (isManager)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final (key, label) in const [('inv', 'Bahan baku'), ('rec', 'Resep & HPP')])
                        ChoiceChip(
                          label: Text(label),
                          selected: view == key,
                          showCheckmark: false,
                          selectedColor: accent,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: view == key ? Colors.white : null,
                          ),
                          onSelected: (_) => setState(() => _view = key),
                        ),
                    ],
                  ),
                ),
              if (view == 'inv') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stok bahan baku',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SubText('Ketersediaan menu dihitung dari stok bahan'),
                        ],
                      ),
                    ),
                    if (isManager && data.ingredients.isNotEmpty)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => _restock(data.ingredients),
                        child: const Text('Beli stok'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const NoteBox(
                  'Menu otomatis berlabel HABIS kalau salah satu bahannya tidak cukup untuk 1 porsi. Stok berkurang sendiri setiap ada penjualan.',
                  amber: true,
                ),
                const SizedBox(height: 10),
                if (data.ingredients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        isManager
                            ? 'Belum ada bahan. Tambahkan di panel web: Daftar Bahan.'
                            : 'Belum ada bahan baku.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted(context)),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final i in data.ingredients)
                        SizedBox(
                          width: cardWidth,
                          child: _IngredientCard(
                            item: i,
                            onRestock: isManager ? () => _restock(data.ingredients, selectedId: i.id) : null,
                          ),
                        ),
                    ],
                  ),
              ] else ...[
                const NoteBox(
                  'Takaran per porsi diatur di panel web: Resep & Bahan. Less Sugar, No Sugar, dan Large ikut menyesuaikan pemakaian bahan.',
                ),
                const SizedBox(height: 10),
                if (data.products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('Belum ada menu', style: TextStyle(color: AppColors.muted(context))),
                    ),
                  )
                else
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final p in data.products)
                        SizedBox(
                          width: cardWidth,
                          child: _RecipeCard(product: p, ingredients: data.ingredients),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.item, required this.onRestock});

  final IngredientInfo item;
  final VoidCallback? onRestock;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final warn = item.isLow;

    final (String label, PillTone tone, Color bar) = item.isOut
        ? ('Habis', PillTone.red, const Color(0xFFDC2626))
        : warn
            ? ('Menipis', PillTone.amber, const Color(0xFFF59E0B))
            : ('Aman', PillTone.green, const Color(0xFF16A34A));

    // Batang penuh bila stok sudah 4x batas minimum
    final full = item.minStock > 0 ? item.minStock * 4 : (item.stock > 0 ? item.stock : 1.0);
    final pct = math.min(1.0, math.max(0.0, item.stock / full));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warn
              ? (dark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
              : AppColors.line(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Stok '),
                          TextSpan(
                            text: '${fmtQty(item.stock)} ${item.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: warn ? const Color(0xFFDC2626) : null,
                            ),
                          ),
                          TextSpan(text: ' · Minimum ${fmtQty(item.minStock)}'),
                        ],
                      ),
                      style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              Pill(label, tone: tone),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: chipFill(context),
              valueColor: AlwaysStoppedAnimation(bar),
            ),
          ),
          if (onRestock != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: onRestock,
                child: const Text('Restock'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resep satu menu: harga, HPP, margin, dan takaran bahan per porsi.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.product, required this.ingredients});

  final Product product;
  final List<IngredientInfo> ingredients;

  @override
  Widget build(BuildContext context) {
    final hasRecipe = product.recipe.isNotEmpty;
    final hpp = product.hpp ?? 0;
    final margin = product.price > 0 ? ((product.price - hpp) / product.price * 100).round() : 0;
    final left = product.portions;

    final Widget badge = left == null
        ? const Pill('Tanpa resep')
        : left <= 0
            ? const Pill('Habis', tone: PillTone.red)
            : left <= 5
                ? Pill('Sisa $left', tone: PillTone.amber)
                : Pill('$left porsi', tone: PillTone.green);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          subtitle: Text(
            hasRecipe
                ? '${rp(product.price)} · HPP ${rp(hpp)} · Margin $margin%'
                : '${rp(product.price)} · Belum ada resep',
            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
          ),
          trailing: badge,
          children: [
            if (!hasRecipe)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Atur takaran di panel web: Resep & Bahan.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted(context)),
                ),
              )
            else
              for (final line in product.recipe)
                Builder(
                  builder: (context) {
                    final ing = ingredients.where((i) => i.id == line.ingredientId).firstOrNull;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        spacing: 8,
                        children: [
                          Flexible(
                            child: Text(ing?.name ?? 'Bahan #${line.ingredientId}', style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text(
                            '${fmtQty(line.quantity)} ${ing?.unit ?? ''}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
