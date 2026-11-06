import 'package:flutter/material.dart';

import 'add_event_sheet.dart';
import 'calendar_screen.dart';
import 'courses_screen.dart';
import 'exams_screen.dart';
import 'format.dart';
import 'navi_mark.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  DateTime _selectedDay = DateTime.now();
  late final AppLifecycleListener _lifecycle;
  String? _lastShownMsg;

  static const _dests = [
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Asignaturas'),
    (Icons.school_outlined, Icons.school, 'Exámenes'),
    (Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => AppScope.read(context).onResume(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).start();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _showMessages() {
    final state = AppScope.read(context);
    final msg = state.error ?? state.info;
    if (msg == null || msg == _lastShownMsg) return;
    _lastShownMsg = msg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor:
              state.error != null ? Theme.of(context).colorScheme.error : null,
          action: state.error != null && !(state.settings?.hasToken ?? false)
              ? SnackBarAction(
                  label: 'Ajustes',
                  onPressed: () => setState(() => _tab = 3),
                )
              : null,
        ));
      state.clearMessages();
      _lastShownMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _showMessages();

    final wide = MediaQuery.of(context).size.width >= 840;
    final pages = [
      CalendarScreen(onDaySelected: (d) => _selectedDay = d),
      const CoursesScreen(),
      const ExamsScreen(),
      const SettingsScreen(),
    ];
    final last = state.settings?.lastCanvasSync;

    final appBar = AppBar(
      titleSpacing: 16,
      title: Row(children: [
        const NaviMark(size: 30),
        const SizedBox(width: 10),
        const Text('NAVI',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
        const SizedBox(width: 12),
        if (!wide && _tab != 0)
          Flexible(
            child: Text(_dests[_tab].$3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
      ]),
      actions: [
        IconButton(
          tooltip: last == null
              ? 'Sincronizar con Canvas'
              : 'Última sincronización: ${fmtDay(last)} ${fmtTime(last)}',
          onPressed: state.syncing ? null : state.syncCanvas,
          icon: state.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync_rounded),
        ),
        const SizedBox(width: 6),
      ],
    );

    final fab = _tab == 3
        ? null
        : FloatingActionButton.extended(
            onPressed: () => showEventSheet(context,
                day: _tab == 0 ? _selectedDay : null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Evento'),
          );

    final body = IndexedStack(index: _tab, children: pages);

    if (wide) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: fab,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _tab,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(
                  icon: Icon(d.$1),
                  selectedIcon: Icon(d.$2),
                  label: Text(d.$3),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: body,
              ),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: fab,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _dests)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
