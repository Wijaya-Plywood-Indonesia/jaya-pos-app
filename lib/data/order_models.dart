import 'dart:math' as math;

import 'models.dart';

/// Metode bayar yang disimpan di database: cash, qris, card.
const paymentLabels = {'cash': 'Tunai', 'qris': 'QRIS', 'card': 'Debit'};

/// 10.0 -> "10", 7.5 -> "7.5"
String fmtPercent(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

enum OrderType {
  dineIn('dine_in', 'Dine In'),
  takeAway('take_away', 'Take Away');

  const OrderType(this.api, this.label);

  /// Nilai yang sama dengan kolom `type` di tabel orders server.
  final String api;
  final String label;

  static OrderType fromApi(String? v) =>
      OrderType.values.firstWhere((t) => t.api == v, orElse: () => OrderType.dineIn);
}

/// "Dine In · Meja 3 · Faris", "Dine In · Faris", atau "Take Away · Faris".
/// Nama pelanggan opsional dan boleh diisi untuk jenis pesanan apa pun.
String orderWhere(OrderType type, {String? tableName, String? customerName}) {
  final name = customerName?.trim() ?? '';

  return [
    type.label,
    if (type == OrderType.dineIn && tableName != null && tableName.isNotEmpty) tableName,
    if (name.isNotEmpty) name,
  ].join(' · ');
}

/// Satu pilihan opsi yang dipilih kasir (misalnya "Large" atau "Less Sugar").
class SelectedOption {
  const SelectedOption({
    required this.optionId,
    required this.name,
    required this.extraPrice,
  });

  final int optionId;
  final String name;
  final int extraPrice;

  factory SelectedOption.fromJson(Map<String, dynamic> j) => SelectedOption(
        optionId: (j['option_id'] as num?)?.toInt() ?? 0,
        name: j['option_name'] as String,
        extraPrice: (j['extra_price'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'option_name': name,
        'extra_price': extraPrice,
      };
}

/// Satu baris di keranjang. Nama dan harga disalin saat ditambahkan,
/// jadi transaksi lama tidak berubah bila menu diedit.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.basePrice,
    required this.qty,
    this.options = const [],
    this.note = '',
  });

  final int productId;
  final String name;
  final int basePrice;
  final int qty;
  final List<SelectedOption> options;
  final String note;

  /// Tambahan harga dari opsi untuk satu porsi.
  int get optionsTotal => options.fold(0, (s, o) => s + o.extraPrice);

  /// Harga satu porsi termasuk opsi.
  int get unitPrice => basePrice + optionsTotal;

  int get lineTotal => unitPrice * qty;

  /// Dua baris dengan menu, opsi, dan catatan yang sama digabung jadi satu.
  String get key {
    final ids = options.map((o) => o.optionId).toList()..sort();
    return '$productId|${ids.join('+')}|$note';
  }

  /// "Large · Less Sugar · “cup terpisah”"
  String get optionsLabel => [
        ...options.map((o) => o.name),
        if (note.isNotEmpty) '“$note”',
      ].join(' · ');

  CartLine copyWith({int? qty}) => CartLine(
        productId: productId,
        name: name,
        basePrice: basePrice,
        qty: qty ?? this.qty,
        options: options,
        note: note,
      );

  /// Bentuk yang sama dengan tabel order_items dan order_item_options di server.
  /// `unit_price` = harga dasar menu, `options_total` = tambahan opsi per satu porsi.
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': name,
        'unit_price': basePrice,
        'quantity': qty,
        'options_total': optionsTotal,
        'line_total': lineTotal,
        'note': note.isEmpty ? null : note,
        'options': options.map((o) => o.toJson()).toList(),
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        name: j['product_name'] as String,
        basePrice: (j['unit_price'] as num).toInt(),
        qty: (j['quantity'] as num).toInt(),
        note: (j['note'] as String?) ?? '',
        options: ((j['options'] as List?) ?? const [])
            .map((e) => SelectedOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Rincian tagihan. Urutannya sama dengan pratinjau struk di panel web:
/// (subtotal - diskon) + service, lalu pajak dari hasilnya, lalu pembulatan.
class OrderTotals {
  const OrderTotals({
    required this.subtotal,
    required this.discount,
    required this.service,
    required this.tax,
    required this.rounding,
    required this.total,
  });

  final int subtotal;
  final int discount;
  final int service;
  final int tax;

  /// Selisih pembulatan, bisa negatif.
  final int rounding;
  final int total;

  static const empty = OrderTotals(
    subtotal: 0,
    discount: 0,
    service: 0,
    tax: 0,
    rounding: 0,
    total: 0,
  );

  factory OrderTotals.compute({
    required int subtotal,
    int discount = 0,
    double servicePercent = 0,
    double taxPercent = 0,
    int roundingStep = 0,
  }) {
    final net = math.max(0, subtotal - discount);
    final service = (net * servicePercent / 100).round();
    final tax = ((net + service) * taxPercent / 100).round();
    final raw = net + service + tax;
    final total = roundingStep > 0 ? (raw / roundingStep).round() * roundingStep : raw;

    return OrderTotals(
      subtotal: subtotal,
      discount: discount,
      service: service,
      tax: tax,
      rounding: total - raw,
      total: total,
    );
  }

  factory OrderTotals.forCart(List<CartLine> lines, Cafe? cafe, {int discount = 0}) {
    return OrderTotals.compute(
      subtotal: lines.fold(0, (s, l) => s + l.lineTotal),
      discount: discount,
      servicePercent: cafe?.servicePercent ?? 0,
      taxPercent: cafe?.taxPercent ?? 0,
      roundingStep: cafe?.rounding ?? 0,
    );
  }
}

/// Transaksi yang sudah dibayar dan tersimpan di tablet.
class PaidOrder {
  const PaidOrder({
    required this.id,
    required this.number,
    required this.cafeId,
    required this.cashierId,
    required this.cashierName,
    required this.type,
    required this.items,
    required this.totals,
    required this.taxPercent,
    required this.servicePercent,
    required this.method,
    required this.cashReceived,
    required this.change,
    required this.orderedAt,
    this.outletId,
    this.shiftId,
    this.tableId,
    this.tableName,
    this.customerName,
    this.status = 'paid',
    this.synced = false,
    this.kitchenStatus = 'new',
  });

  final String id;
  final String number;
  final int cafeId;
  final int? outletId;
  final String? shiftId;
  final int cashierId;
  final String cashierName;
  final OrderType type;
  final int? tableId;
  final String? tableName;
  final String? customerName;
  final List<CartLine> items;
  final OrderTotals totals;
  final double taxPercent;
  final double servicePercent;

  /// cash, qris, card
  final String method;
  final int cashReceived;
  final int change;
  final DateTime orderedAt;

  /// paid atau void (void dipakai di langkah berikutnya).
  final String status;

  /// Sudah terkirim ke server atau belum.
  final bool synced;

  /// Status antrian: new (baru), ready (siap diambil), served (sudah diserahkan).
  final String kitchenStatus;

  String get where => orderWhere(type, tableName: tableName, customerName: customerName);

  String get methodLabel => paymentLabels[method] ?? method;

  int get itemCount => items.fold(0, (s, l) => s + l.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': number,
        'cafe_id': cafeId,
        'outlet_id': outletId,
        'shift_id': shiftId,
        'cashier_id': cashierId,
        'cashier_name': cashierName,
        'type': type.api,
        'dining_table_id': tableId,
        'table_name': tableName,
        'customer_name': (customerName == null || customerName!.trim().isEmpty)
            ? null
            : customerName!.trim(),
        'status': status,
        'kitchen_status': kitchenStatus,
        'items': items.map((l) => l.toJson()).toList(),
        'subtotal': totals.subtotal,
        'discount_total': totals.discount,
        'service_amount': totals.service,
        'tax_amount': totals.tax,
        'rounding': totals.rounding,
        'total': totals.total,
        'tax_percent': taxPercent,
        'service_percent': servicePercent,
        'payment': {
          'method': method,
          'amount': totals.total,
          'cash_received': method == 'cash' ? cashReceived : null,
          'change_amount': change,
        },
                // UTC, supaya server tahu jam sebenarnya
        'ordered_at': orderedAt.toUtc().toIso8601String(),
        'paid_at': orderedAt.toUtc().toIso8601String(),
      };

  factory PaidOrder.fromJson(
    Map<String, dynamic> j, {
    bool synced = false,
    String? status,
    String? kitchenStatus,
  }) {
    final pay = (j['payment'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;

    return PaidOrder(
      id: j['id'] as String,
      number: j['order_number'] as String,
      cafeId: n('cafe_id'),
      outletId: (j['outlet_id'] as num?)?.toInt(),
      shiftId: j['shift_id'] as String?,
      cashierId: n('cashier_id'),
      cashierName: (j['cashier_name'] as String?) ?? '-',
      type: OrderType.fromApi(j['type'] as String?),
      tableId: (j['dining_table_id'] as num?)?.toInt(),
      tableName: j['table_name'] as String?,
      customerName: j['customer_name'] as String?,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: OrderTotals(
        subtotal: n('subtotal'),
        discount: n('discount_total'),
        service: n('service_amount'),
        tax: n('tax_amount'),
        rounding: n('rounding'),
        total: n('total'),
      ),
      taxPercent: (j['tax_percent'] as num?)?.toDouble() ?? 0,
      servicePercent: (j['service_percent'] as num?)?.toDouble() ?? 0,
      method: (pay['method'] as String?) ?? 'cash',
      cashReceived: (pay['cash_received'] as num?)?.toInt() ?? 0,
      change: (pay['change_amount'] as num?)?.toInt() ?? 0,
      orderedAt: DateTime.parse(j['ordered_at'] as String).toLocal(),
      status: status ?? (j['status'] as String?) ?? 'paid',
      synced: synced,
      kitchenStatus: kitchenStatus ?? (j['kitchen_status'] as String?) ?? 'new',
    );
  }
}