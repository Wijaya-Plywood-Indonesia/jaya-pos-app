import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/order_models.dart';
import '../session/session_controller.dart';

class CartState {
  const CartState({
    this.lines = const [],
    this.type = OrderType.dineIn,
    this.tableId,
    this.customerName = '',
  });

  final List<CartLine> lines;
  final OrderType type;
  final int? tableId;
  final String customerName;

  bool get isEmpty => lines.isEmpty;

  /// Jumlah porsi (bukan jumlah baris).
  int get count => lines.fold(0, (s, l) => s + l.qty);

  CartState copyWith({
    List<CartLine>? lines,
    OrderType? type,
    int? tableId,
    bool clearTable = false,
    String? customerName,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      type: type ?? this.type,
      tableId: clearTable ? null : (tableId ?? this.tableId),
      customerName: customerName ?? this.customerName,
    );
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Rincian tagihan pesanan aktif, dihitung dari pengaturan pajak, service,
/// dan pembulatan cafe.
final cartTotalsProvider = Provider<OrderTotals>((ref) {
  final cart = ref.watch(cartProvider);
  final cafe = ref.watch(sessionProvider.select((s) => s.value?.cafe));

  return OrderTotals.forCart(cart.lines, cafe);
});

class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    // Ganti akun atau keluar: pesanan yang belum dibayar tidak ikut terbawa
    ref.watch(sessionProvider.select((s) => s.value?.user?.id));

    return const CartState();
  }

  void add(CartLine line) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.key == line.key);

    if (i >= 0) {
      lines[i] = lines[i].copyWith(qty: lines[i].qty + line.qty);
    } else {
      lines.add(line);
    }

    state = state.copyWith(lines: lines);
  }

  /// [qty] <= 0 menghapus baris.
  void setQty(String key, int qty) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.key == key);
    if (i < 0) return;

    if (qty <= 0) {
      lines.removeAt(i);
    } else {
      lines[i] = lines[i].copyWith(qty: qty);
    }

    state = state.copyWith(lines: lines);
  }

  void setType(OrderType type) => state = state.copyWith(type: type);

  void setTable(int? id) {
    state = id == null ? state.copyWith(clearTable: true) : state.copyWith(tableId: id);
  }

  void setName(String name) => state = state.copyWith(customerName: name);

  /// Kosongkan pesanan. Jenis pesanan (Dine In / Take Away) tetap dipertahankan.
  void clear() => state = CartState(type: state.type);
}
