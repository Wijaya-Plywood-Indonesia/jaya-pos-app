import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/sheet.dart';
import '../session/session_controller.dart';

/// Owner atau manajer yang menyetujui sebuah tindakan.
class Approver {
  const Approver({required this.id, required this.name});

  final int id;
  final String name;
}

/// Minta PIN owner atau manajer. Mengembalikan penyetujunya, atau null bila dibatalkan.
///
/// PIN owner tidak pernah disimpan di tablet, jadi pemeriksaannya lewat server dan
/// butuh internet. Owner atau manajer yang sedang login tidak perlu PIN ini.
Future<Approver?> showApproverSheet(BuildContext context, {required String reason}) {
  return showAppSheet<Approver>(context, (_) => ApproverSheet(reason: reason));
}

class ApproverSheet extends ConsumerStatefulWidget {
  const ApproverSheet({super.key, required this.reason});

  final String reason;

  @override
  ConsumerState<ApproverSheet> createState() => _ApproverSheetState();
}

class _ApproverSheetState extends ConsumerState<ApproverSheet> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text.trim();

    if (pin.length != 4) {
      setState(() => _error = 'PIN terdiri dari 4 angka');
      return;
    }

    final s = ref.read(sessionProvider).value;
    final baseUrl = s?.baseUrl;
    final token = s?.token;

    if (baseUrl == null || token == null) {
      setState(() => _error = 'Butuh internet. Masuk lagi saat online, atau minta owner masuk dengan akunnya.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await Api(baseUrl, token: token).post(
        '/auth/verify-approver',
        data: {'pin': pin},
      );

      final a = res['approver'] as Map<String, dynamic>;
      if (!mounted) return;

      Navigator.pop(
        context,
        Approver(id: (a['id'] as num).toInt(), name: a['name'] as String),
      );
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
        _error = 'PIN gagal diperiksa. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'PIN owner',
      onClose: _busy ? null : () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SubText('${widget.reason} perlu persetujuan owner atau manajer.'),
          AppField(
            controller: _pin,
            hint: 'PIN owner (4 angka)',
            obscure: true,
            maxLength: 4,
            autofocus: true,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ],
      ),
      footer: DarkButton(
        label: _busy ? 'Memeriksa...' : 'Setujui',
        onPressed: _busy ? null : _submit,
      ),
    );
  }
}
