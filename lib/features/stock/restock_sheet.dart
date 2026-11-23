import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'stock_controller.dart';

/// Beli stok. Mengembalikan true bila pembelian tersimpan.
Future<bool?> showRestockSheet(
  BuildContext context, {
  required List<IngredientInfo> ingredients,
  int? selectedId,
}) {
  return showAppSheet<bool>(
    context,
    (_) => RestockSheet(ingredients: ingredients, selectedId: selectedId),
  );
}

class RestockSheet extends ConsumerStatefulWidget {
  const RestockSheet({super.key, required this.ingredients, this.selectedId});

  final List<IngredientInfo> ingredients;
  final int? selectedId;

  @override
  ConsumerState<RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends ConsumerState<RestockSheet> {
  final _qty = TextEditingController();
  late int? _id = widget.selectedId ??
      (widget.ingredients.isEmpty ? null : widget.ingredients.first.id);
  String? _error;
  bool _busy = false;

  IngredientInfo? get _item => widget.ingredients.where((i) => i.id == _id).firstOrNull;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final item = _item;
    final qty = parseRupiah(_qty.text);

    if (item == null) {
      setState(() => _error = 'Pilih bahan dulu');
      return;
    }

    if (qty <= 0) {
      setState(() => _error = 'Isi jumlah pembelian dulu');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await restockIngredient(ref, ingredientId: item.id, quantity: qty.toDouble());

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Pembelian gagal disimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final qty = parseRupiah(_qty.text);
    final cost = item?.costPerUnit;

    return AppSheet(
      title: 'Beli stok',
      onClose: _busy ? null : () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Bahan'),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: fieldFill(context),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line(context), width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _id,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: [
                      for (final i in widget.ingredients)
                        DropdownMenuItem(
                          value: i.id,
                          child: Text(i.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _id = v),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Jumlah dibeli${item == null ? '' : ' (${item.unit})'}'),
              AppField(
                controller: _qty,
                hint: 'Masukkan jumlah',
                digitsOnly: true,
                errorText: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
          if (item != null)
            InfoBox(
              child: Column(
                children: [
                  InfoRow('Stok sekarang', '${fmtQty(item.stock)} ${item.unit}'),
                  if (qty > 0)
                    InfoRow('Stok setelah dibeli', '${fmtQty(item.stock + qty)} ${item.unit}'),
                  if (cost != null && qty > 0)
                    InfoRow('Biaya (dicatat sebagai pengeluaran)', rp((qty * cost).round()), bold: true),
                ],
              ),
            ),
        ],
      ),
      footer: DarkButton(
        label: _busy ? 'Menyimpan...' : 'Simpan pembelian',
        onPressed: _busy ? null : _submit,
      ),
    );
  }
}
