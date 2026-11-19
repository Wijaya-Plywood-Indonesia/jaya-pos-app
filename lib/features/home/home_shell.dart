import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../history/history_screen.dart';
import '../pos/pos_screen.dart';
import '../session/connection_chip.dart';
import '../session/session_controller.dart';
import '../shift/shift_controller.dart';
import '../shift/shift_widgets.dart';
import '../pos/pos_widgets.dart';
import '../pos/sync_controller.dart';

const _navBg = Color(0xFF111111);
const _navIdle = Color(0xFF9CA3AF);

class _TabDef {
  _TabDef(this.label, this.title, this.icon, this.builder);

  final String label;
  final String title;
  final IconData icon;
  final Widget Function() builder;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();

    // Aplikasi dibuka atau akun masuk: kirim yang tertunda, termasuk yang sempat ditolak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncProvider.notifier).run(retryFailed: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value?.user;
    if (user == null) return const SizedBox.shrink();

    // "Online lagi. N transaksi disinkronkan"
    ref.listen(syncProvider.select((s) => s.batchId), (prev, next) {
      final sync = ref.read(syncProvider);
      if (sync.announce && sync.lastBatch > 0) {
        showToast(context, 'Online lagi. ${sync.lastBatch} transaksi disinkronkan');
      }
    });

    final shift = ref.watch(shiftProvider);
    final isOwner = user.role == 'owner';

    final tabs = <_TabDef>[
      _TabDef('Kasir', 'Kasir', Icons.shopping_bag_outlined, () => const PosScreen()),
      _TabDef(
        'Antrian',
        'Antrian pesanan',
        Icons.format_list_bulleted,
        () => const _ComingSoon(
          icon: Icons.format_list_bulleted,
          text: 'Antrian dapur: pesanan Baru dan Siap diambil.',
        ),
      ),
      _TabDef(
        'Riwayat',
        'Riwayat transaksi',
        Icons.receipt_long_outlined,
        () => const HistoryScreen(),
      ),
      _TabDef(
        'Stok',
        'Stok dan resep',
        Icons.inventory_2_outlined,
        () => const _ComingSoon(
          icon: Icons.inventory_2_outlined,
          text: 'Stok bahan baku, restock, dan resep.',
        ),
      ),
      if (isOwner)
        _TabDef(
          'Laporan',
          'Laporan',
          Icons.show_chart,
          () => const _ComingSoon(
            icon: Icons.show_chart,
            text: 'Omset, laba rugi, menu terlaris, dan ekspor.',
          ),
        ),
    ];

    final index = _index.clamp(0, tabs.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final content = Column(
      children: [
        _Header(
          title: tabs[index].title,
          onAccount: () => showAccountDialog(context, ref),
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [for (final t in tabs) t.builder()],
          ),
        ),
      ],
    );

    final nav = _Nav(
      tabs: tabs,
      index: index,
      vertical: wide,
      onTap: (i) => setState(() => _index = i),
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            wide
                ? Row(children: [nav, Expanded(child: content)])
                : Column(children: [Expanded(child: content), nav]),
            // Belum ada shift: kasir wajib mengisi kas awal dulu
            if (shift.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x8C000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (shift.hasValue && shift.value == null)
              const Positioned.fill(child: _ShiftGate()),
          ],
        ),
      ),
    );
  }
}

class _ShiftGate extends StatelessWidget {
  const _ShiftGate();

  @override
  Widget build(BuildContext context) {
        return const Stack(
      children: [
        ModalBarrier(dismissible: false, color: Color(0x8C000000)),
        Center(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: ShiftOpenCard(),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.onAccount});

  final String title;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(bottom: BorderSide(color: AppColors.line(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const ConnectionChip(),
          const SizedBox(width: 10),
          if (user != null)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onAccount,
              child: Avatar(name: user.name, owner: user.role == 'owner', size: 36),
            ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({
    required this.tabs,
    required this.index,
    required this.vertical,
    required this.onTap,
  });

  final List<_TabDef> tabs;
  final int index;
  final bool vertical;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final items = [
      for (var i = 0; i < tabs.length; i++)
        _NavItem(
          label: tabs[i].label,
          icon: tabs[i].icon,
          active: i == index,
          onTap: () => onTap(i),
        ),
    ];

    if (vertical) {
      return Container(
        width: 84,
        color: _navBg,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Center(child: Icon(Icons.local_cafe_outlined, color: primary, size: 26)),
            ),
            const SizedBox(height: 6),
            ...items,
          ],
        ),
      );
    }

    return Container(
      height: 64,
      color: _navBg,
      child: Row(children: [for (final i in items) Expanded(child: i)]),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 64,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: active ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 19, color: active ? Colors.white : _navIdle),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _navIdle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted(context)),
            const SizedBox(height: 12),
            const Text('Segera hadir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted(context)),
            ),
          ],
        ),
      ),
    );
  }
}