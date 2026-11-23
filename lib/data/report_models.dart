/// Ringkasan penjualan dari server (GET /v1/reports/summary).
class ReportData {
  const ReportData({
    required this.label,
    required this.rangeText,
    required this.bucket,
    required this.salesGross,
    required this.discount,
    required this.salesNet,
    required this.hpp,
    required this.grossProfit,
    required this.margin,
    required this.transactions,
    required this.average,
    required this.service,
    required this.tax,
    required this.rounding,
    required this.totalReceived,
    required this.expenses,
    required this.payments,
    required this.series,
    required this.top,
  });

  final String label;
  final String rangeText;

  /// hour atau day
  final String bucket;
  final int salesGross;
  final int discount;
  final int salesNet;
  final int hpp;
  final int grossProfit;
  final int margin;
  final int transactions;
  final int average;
  final int service;
  final int tax;
  final int rounding;
  final int totalReceived;
  final int expenses;
  final List<ReportPayment> payments;
  final List<ReportPoint> series;
  final List<ReportTop> top;

  factory ReportData.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;

    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

    return ReportData(
      label: (j['label'] as String?) ?? '',
      rangeText: (j['range_text'] as String?) ?? '',
      bucket: (j['bucket'] as String?) ?? 'day',
      salesGross: n('sales_gross'),
      discount: n('discount'),
      salesNet: n('sales_net'),
      hpp: n('hpp'),
      grossProfit: n('gross_profit'),
      margin: n('margin'),
      transactions: n('transactions'),
      average: n('average'),
      service: n('service'),
      tax: n('tax'),
      rounding: n('rounding'),
      totalReceived: n('total_received'),
      expenses: n('expenses'),
      payments: list('payments', ReportPayment.fromJson),
      series: list('series', ReportPoint.fromJson),
      top: list('top', ReportTop.fromJson),
    );
  }
}

class ReportPayment {
  const ReportPayment({
    required this.method,
    required this.label,
    required this.amount,
    required this.pct,
  });

  final String method;
  final String label;
  final int amount;
  final int pct;

  factory ReportPayment.fromJson(Map<String, dynamic> j) => ReportPayment(
        method: j['method'] as String,
        label: (j['label'] as String?) ?? (j['method'] as String),
        amount: (j['amount'] as num).toInt(),
        pct: (j['pct'] as num?)?.toInt() ?? 0,
      );
}

class ReportPoint {
  const ReportPoint({required this.label, required this.value});

  final String label;
  final int value;

  factory ReportPoint.fromJson(Map<String, dynamic> j) => ReportPoint(
        label: j['label'].toString(),
        value: (j['value'] as num).toInt(),
      );
}

class ReportTop {
  const ReportTop({required this.name, required this.qty, required this.revenue});

  final String name;
  final int qty;
  final int revenue;

  factory ReportTop.fromJson(Map<String, dynamic> j) => ReportTop(
        name: j['name'] as String,
        qty: (j['qty'] as num).toInt(),
        revenue: (j['revenue'] as num).toInt(),
      );
}
