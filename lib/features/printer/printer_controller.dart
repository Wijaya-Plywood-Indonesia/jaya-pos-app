import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/theme_mode.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import 'receipt_printer.dart';

/// Printer Bluetooth yang sudah dipasangkan di pengaturan Bluetooth perangkat.
class PrinterDevice {
  const PrinterDevice({required this.name, required this.mac});

  final String name;
  final String mac;
}

class PrintResult {
  const PrintResult(this.ok, this.message);

  final bool ok;
  final String message;
}

class PrinterException implements Exception {
  const PrinterException(this.message);

  final String message;
}

class PrinterState {
  const PrinterState({
    this.mac,
    this.name,
    this.paperMm = 58,
    this.auto = false,
    this.busy = false,
  });

  final String? mac;
  final String? name;

  /// Lebar kertas: 58 atau 80 (mm)
  final int paperMm;

  /// Cetak struk otomatis setelah pembayaran
  final bool auto;
  final bool busy;

  bool get hasPrinter => mac != null;

  PrinterState copyWith({
    String? mac,
    String? name,
    bool clearPrinter = false,
    int? paperMm,
    bool? auto,
    bool? busy,
  }) {
    return PrinterState(
      mac: clearPrinter ? null : (mac ?? this.mac),
      name: clearPrinter ? null : (name ?? this.name),
      paperMm: paperMm ?? this.paperMm,
      auto: auto ?? this.auto,
      busy: busy ?? this.busy,
    );
  }
}

final printerProvider = NotifierProvider<PrinterController, PrinterState>(PrinterController.new);

/// Mengatur dan memakai printer struk Bluetooth. Pilihan printer, lebar kertas, dan
/// cetak otomatis tersimpan di perangkat dan berlaku untuk semua akun.
class PrinterController extends Notifier<PrinterState> {
  static const _kMac = 'printer_mac';
  static const _kName = 'printer_name';
  static const _kPaper = 'printer_paper_mm';
  static const _kAuto = 'printer_auto';

  @override
  PrinterState build() {
    final prefs = ref.read(prefsProvider);

    return PrinterState(
      mac: prefs.getString(_kMac),
      name: prefs.getString(_kName),
      paperMm: prefs.getInt(_kPaper) ?? 58,
      auto: prefs.getBool(_kAuto) ?? false,
    );
  }

  /// Izin Bluetooth (Android 12 ke atas) dan Bluetooth harus menyala.
  Future<void> _ensureReady() async {
    final results = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();

    if (results.values.any((s) => !s.isGranted)) {
      throw const PrinterException(
        'Izin Bluetooth ditolak. Buka Pengaturan aplikasi dan izinkan "Perangkat di sekitar".',
      );
    }

    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrinterException('Bluetooth masih mati. Nyalakan Bluetooth dulu.');
    }
  }

  /// Printer yang sudah dipasangkan di Bluetooth perangkat ini.
  Future<List<PrinterDevice>> pairedDevices() async {
    await _ensureReady();

    final list = await PrintBluetoothThermal.pairedBluetooths;

    return [for (final d in list) PrinterDevice(name: d.name, mac: d.macAdress)];
  }

  Future<void> select(PrinterDevice device) async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    final prefs = ref.read(prefsProvider);
    await prefs.setString(_kMac, device.mac);
    await prefs.setString(_kName, device.name);

    state = state.copyWith(mac: device.mac, name: device.name);
  }

  Future<void> forget() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    final prefs = ref.read(prefsProvider);
    await prefs.remove(_kMac);
    await prefs.remove(_kName);

    state = state.copyWith(clearPrinter: true);
  }

  Future<void> setPaper(int mm) async {
    await ref.read(prefsProvider).setInt(_kPaper, mm);
    state = state.copyWith(paperMm: mm);
  }

  Future<void> setAuto(bool on) async {
    await ref.read(prefsProvider).setBool(_kAuto, on);
    state = state.copyWith(auto: on);
  }

  Future<void> _connect() async {
    final mac = state.mac;

    if (mac == null) {
      throw const PrinterException('Belum ada printer dipilih. Pilih printer di Pengaturan printer.');
    }

    await _ensureReady();

    if (await PrintBluetoothThermal.connectionStatus) return;

    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);

    if (!ok) {
      throw const PrinterException(
        'Printer tidak terjangkau. Pastikan printer menyala, dekat dengan tablet, dan tidak sedang tersambung ke perangkat lain.',
      );
    }
  }

  Future<PrintResult> _send(List<int> bytes) async {
    if (state.busy) return const PrintResult(false, 'Printer masih mencetak. Tunggu sebentar.');

    state = state.copyWith(busy: true);

    try {
      await _connect();

      // Dikirim bertahap: printer murah punya penampung kecil dan bisa kehilangan data
      const chunk = 480;
      for (var i = 0; i < bytes.length; i += chunk) {
        final part = bytes.sublist(i, math.min(i + chunk, bytes.length));

        if (!await PrintBluetoothThermal.writeBytes(part)) {
          try {
            await PrintBluetoothThermal.disconnect;
          } catch (_) {}

          throw const PrinterException('Pengiriman ke printer terputus. Coba cetak lagi.');
        }

        await Future.delayed(const Duration(milliseconds: 40));
      }

      return const PrintResult(true, 'Struk dikirim ke printer.');
    } on PrinterException catch (e) {
      return PrintResult(false, e.message);
    } catch (_) {
      return const PrintResult(
        false,
        'Printer gagal dipakai. Periksa Bluetooth dan printer, lalu coba lagi.',
      );
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<PrintResult> printReceipt(PaidOrder order, Cafe? cafe) {
    return _send(ReceiptPrinter.build(order, cafe, paperMm: state.paperMm));
  }

  Future<PrintResult> printTest() {
    return _send(ReceiptPrinter.test(paperMm: state.paperMm, printerName: state.name));
  }
}
