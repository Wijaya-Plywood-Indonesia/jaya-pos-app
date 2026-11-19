import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import 'cart_controller.dart';
import 'pos_widgets.dart';

/// Buka lembar opsi menu. Mengembalikan baris yang ditambahkan ke keranjang,
/// atau null bila kasir menutupnya.
Future<CartLine?> showOptionSheet(
  BuildContext context, {
  required Product product,
  required List<OptionGroup> groups,
}) {
  return showAppSheet<CartLine>(
    context,
    (_) => OptionSheet(product: product, groups: groups),
  );
}

class OptionSheet extends ConsumerStatefulWidget {
  const OptionSheet({super.key, required this.product, required this.groups});

  final Product product;
  final List<OptionGroup> groups;

  @override
  ConsumerState<OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends ConsumerState<OptionSheet> {
  final _note = TextEditingController();

  /// id grup -> id opsi yang dipilih
  final Map<int, Set<int>> _picked = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();

    for (final g in widget.groups) {
      _picked[g.id] = {};

      // Grup wajib pilih satu: pilihan pertama langsung terpilih (seperti "Normal" di mockup)
      if (g.isRequired && !g.isMultiple && g.options.isNotEmpty) {
        _picked[g.id]!.add(g.options.first.id);
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<SelectedOption> get _selected => [
        for (final g in widget.groups)
          for (final o in g.options)
            if (_picked[g.id]!.contains(o.id))
              SelectedOption(optionId: o.id, name: o.name, extraPrice: o.extraPrice),
      ];

  int get _extra => _selected.fold(0, (s, o) => s + o.extraPrice);

  bool get _valid => widget.groups.every((g) => !g.isRequired || _picked[g.id]!.isNotEmpty);

  void _toggle(OptionGroup g, OptionItem o) {
    setState(() {
      final set = _picked[g.id]!;

      if (g.isMultiple) {
        if (set.contains(o.id)) {
          set.remove(o.id);
        } else {
          set.add(o.id);
        }
      } else if (set.contains(o.id)) {
        // Grup boleh kosong: ketuk lagi untuk melepas pilihan
        if (!g.isRequired) set.clear();
      } else {
        set
          ..clear()
          ..add(o.id);
      }
    });
  }

  void _add() {
    final p = widget.product;

    final line = CartLine(
      productId: p.id,
      name: p.name,
      basePrice: p.price,
      options: _selected,
      qty: _qty,
      note: _note.text.trim(),
    );

    ref.read(cartProvider.notifier).add(line);
    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return AppSheet(
      title: p.name,
      onClose: () => Navigator.pop(context),
      body: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in widget.groups)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel(g.isRequired ? g.name : '${g.name} (opsional)'),
                _OptionGrid(
                  group: g,
                  picked: _picked[g.id]!,
                  onTap: (o) => _toggle(g, o),
                ),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Jumlah'),
              Align(
                alignment: Alignment.centerLeft,
                child: QtyStepper(
                  value: _qty,
                  size: 40,
                  min: 1,
                  onChanged: (v) => setState(() => _qty = v),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Catatan'),
              NoteField(controller: _note, hint: 'Contoh: cup terpisah'),
            ],
          ),
        ],
      ),
      footer: FilledButton(
        onPressed: _valid ? _add : null,
        child: Text('Tambah · ${rp((p.price + _extra) * _qty)}'),
      ),
    );
  }
}

/// Pilihan dalam kisi 2 atau 3 kolom, seperti ".segs" di mockup.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.group, required this.picked, required this.onTap});

  final OptionGroup group;
  final Set<int> picked;
  final ValueChanged<OptionItem> onTap;

  @override
  Widget build(BuildContext context) {
    final n = group.options.length;
    final cols = (n == 2 || n == 4) ? 2 : 3;
    const gap = 7.0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final o in group.options)
              SizedBox(
                width: w,
                child: PickButton(
                  label: o.name,
                  sub: o.extraPrice > 0 ? '+${rp(o.extraPrice)}' : null,
                  selected: picked.contains(o.id),
                  onTap: () => onTap(o),
                ),
              ),
          ],
        );
      },
    );
  }
}
