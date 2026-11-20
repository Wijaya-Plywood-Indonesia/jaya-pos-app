class Cafe {
  const Cafe({
    required this.id,
    required this.name,
    required this.slug,
    required this.themeColor,
    required this.taxPercent,
    required this.servicePercent,
    required this.rounding,
    this.receiptFooter,
  });

  final int id;
  final String name;
  final String slug;
  final String themeColor;
  final double taxPercent;
  final double servicePercent;
  final int rounding;
  final String? receiptFooter;

  factory Cafe.fromJson(Map<String, dynamic> j) => Cafe(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        slug: j['slug'] as String,
        themeColor: (j['theme_color'] as String?) ?? '#DC2626',
        taxPercent: (j['tax_percent'] as num?)?.toDouble() ?? 0,
        servicePercent: (j['service_percent'] as num?)?.toDouble() ?? 0,
        rounding: (j['rounding'] as num?)?.toInt() ?? 0,
        receiptFooter: j['receipt_footer'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'theme_color': themeColor,
        'tax_percent': taxPercent,
        'service_percent': servicePercent,
        'rounding': rounding,
        'receipt_footer': receiptFooter,
      };
}

class Staff {
  const Staff({required this.id, required this.name, this.role, this.outletId});

  final int id;
  final String name;
  final String? role;
  final int? outletId;

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        role: j['role'] as String?,
        outletId: (j['outlet_id'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'outlet_id': outletId,
      };
}

/// Salinan daftar staf untuk login offline.
/// [pins] hanya berisi hash PIN milik kasir (id staf -> hash bcrypt).
class OfflineStaff {
  const OfflineStaff({required this.staff, required this.pins});

  final List<Staff> staff;
  final Map<int, String> pins;

  bool canLoginOffline(int userId) => pins.containsKey(userId);

  factory OfflineStaff.fromJson(Map<String, dynamic> j) {
    final rawPins = (j['pins'] as Map?) ?? const {};
    return OfflineStaff(
      staff: _list(j['staff'], Staff.fromJson),
      pins: {
        for (final e in rawPins.entries) int.parse(e.key.toString()): e.value as String,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'staff': staff.map((s) => s.toJson()).toList(),
        'pins': {for (final e in pins.entries) '${e.key}': e.value},
      };
}

class AppUser {
  const AppUser({required this.id, required this.name, this.role, this.outletId});

  final int id;
  final String name;
  final String? role;
  final int? outletId;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        role: j['role'] as String?,
        outletId: (j['outlet_id'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'outlet_id': outletId,
      };
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
      );
}

class OptionItem {
  const OptionItem({required this.id, required this.name, required this.extraPrice});

  final int id;
  final String name;
  final int extraPrice;

  factory OptionItem.fromJson(Map<String, dynamic> j) => OptionItem(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        extraPrice: (j['extra_price'] as num?)?.toInt() ?? 0,
      );
}

class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.isMultiple,
    required this.isRequired,
    required this.options,
  });

  final int id;
  final String name;
  final bool isMultiple;
  final bool isRequired;
  final List<OptionItem> options;

  factory OptionGroup.fromJson(Map<String, dynamic> j) => OptionGroup(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        isMultiple: (j['is_multiple'] as bool?) ?? false,
        isRequired: (j['is_required'] as bool?) ?? false,
        options: _list(j['options'], OptionItem.fromJson),
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.optionGroupIds,
    this.categoryId,
    this.imagePath,
  });

  final int id;
  final String name;
  final int price;
  final bool isAvailable;
  final int? categoryId;
  final String? imagePath;
  final List<int> optionGroupIds;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        isAvailable: (j['is_available'] as bool?) ?? true,
        categoryId: (j['category_id'] as num?)?.toInt(),
        imagePath: j['image_path'] as String?,
        optionGroupIds: ((j['option_group_ids'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

class DiningTableInfo {
  const DiningTableInfo({required this.id, required this.name, this.capacity});

  final int id;
  final String name;
  final int? capacity;

  factory DiningTableInfo.fromJson(Map<String, dynamic> j) => DiningTableInfo(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        capacity: (j['capacity'] as num?)?.toInt(),
      );
}

/// Promo atau voucher dari server. Voucher = punya [code]; promo biasa tanpa kode.
class DiscountInfo {
  const DiscountInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.code,
    this.minPurchase = 0,
    this.maxDiscount,
    this.startsAt,
    this.endsAt,
  });

  final int id;
  final String name;
  final String? code;

  /// percent atau amount
  final String type;
  final int value;
  final int minPurchase;
  final int? maxDiscount;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isVoucher => code != null && code!.isNotEmpty;

  /// Masih berlaku pada waktu [t]? Dicek lagi di tablet karena menu bisa berasal dari
  /// salinan lama saat offline.
  bool activeAt(DateTime t) =>
      (startsAt == null || !t.isBefore(startsAt!)) && (endsAt == null || !t.isAfter(endsAt!));

  factory DiscountInfo.fromJson(Map<String, dynamic> j) => DiscountInfo(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        code: j['code'] as String?,
        type: j['type'] as String,
        value: (j['value'] as num).toInt(),
        minPurchase: (j['min_purchase'] as num?)?.toInt() ?? 0,
        maxDiscount: (j['max_discount'] as num?)?.toInt(),
        startsAt: DateTime.tryParse((j['starts_at'] as String?) ?? '')?.toLocal(),
        endsAt: DateTime.tryParse((j['ends_at'] as String?) ?? '')?.toLocal(),
      );
}

class MenuData {
  const MenuData({
    required this.categories,
    required this.optionGroups,
    required this.products,
    required this.tables,
    this.discounts = const [],
  });

  final List<MenuCategory> categories;
  final List<OptionGroup> optionGroups;
  final List<Product> products;
  final List<DiningTableInfo> tables;
  final List<DiscountInfo> discounts;

  factory MenuData.fromJson(Map<String, dynamic> j) => MenuData(
        categories: _list(j['categories'], MenuCategory.fromJson),
        optionGroups: _list(j['option_groups'], OptionGroup.fromJson),
        products: _list(j['products'], Product.fromJson),
        tables: _list(j['tables'], DiningTableInfo.fromJson),
        discounts: _list(j['discounts'], DiscountInfo.fromJson),
      );
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) from) {
  final items = (raw as List?) ?? const [];
  return items.map((e) => from(e as Map<String, dynamic>)).toList();
}