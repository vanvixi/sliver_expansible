import 'package:flutter/material.dart';
import 'package:sliver_expansion/sliver_expansion.dart';

void main() {
  runApp(const SliverExpansionExampleApp());
}

class SliverExpansionExampleApp extends StatefulWidget {
  const SliverExpansionExampleApp({super.key});

  @override
  State<SliverExpansionExampleApp> createState() =>
      _SliverExpansionExampleAppState();
}

class _SliverExpansionExampleAppState extends State<SliverExpansionExampleApp> {
  bool _pinnedHeader = true;
  bool _maintainState = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sliver Expansion Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return SliverExpansionExampleSettings(
          pinnedHeader: _pinnedHeader,
          maintainState: _maintainState,
          togglePinnedHeader: () =>
              setState(() => _pinnedHeader = !_pinnedHeader),
          toggleMaintainState: () =>
              setState(() => _maintainState = !_maintainState),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SliverExpansibleExamplePage(),
    );
  }
}

class SliverExpansibleExamplePage extends StatelessWidget {
  const SliverExpansibleExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SliverExpansionExampleSettings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SliverExpansible'),
        actions: const [_SettingsMenuButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: CustomScrollView(
          slivers: [
            SliverExpansibleTitleCustom(
              key: const PageStorageKey<String>('section-a'),
              title: 'Section A',
              itemCount: 4,
              pinnedHeader: settings.pinnedHeader,
              maintainState: settings.maintainState,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverExpansibleTitleCustom(
              key: const PageStorageKey<String>('section-b'),
              title: 'Section B',
              itemCount: 4,
              pinnedHeader: settings.pinnedHeader,
              maintainState: settings.maintainState,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverExpansibleTitleCustom(
              key: const PageStorageKey<String>('section-c'),
              title: 'Section C',
              itemCount: 4,
              pinnedHeader: settings.pinnedHeader,
              maintainState: settings.maintainState,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverExpansibleTitleCustom(
              key: const PageStorageKey<String>('section-d'),
              title: 'Section D',
              itemCount: 4,
              pinnedHeader: settings.pinnedHeader,
              maintainState: settings.maintainState,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: ExpansionTile(
                title: const Text('Non-sliver expansion tile'),
                backgroundColor: Colors.lightGreen,
                collapsedBackgroundColor: Colors.lightGreen,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                collapsedShape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                children: [
                  for (int i = 0; i < 4; i++)
                    ListTile(
                      dense: true,
                      title: Text('Item #$i'),
                      subtitle: Text('Subtitle #$i'),
                      trailing: const Icon(Icons.info_outline),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class SliverExpansibleTitleCustom extends StatelessWidget {
  const SliverExpansibleTitleCustom({
    required this.title,
    required this.itemCount,
    required this.maintainState,
    required this.pinnedHeader,
    super.key,
  });

  final String title;
  final int itemCount;
  final bool maintainState;
  final bool pinnedHeader;

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[title.hashCode % Colors.primaries.length];
    return SliverExpansionTile(
      title: Text(title),
      pinned: pinnedHeader,
      maintainState: maintainState,
      backgroundColor: color,
      collapsedBackgroundColor: color,
      pinnedHeaderColor: color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      collapsedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      children: [
        for (int i = 0; i < itemCount; i++)
          ListTile(
            dense: true,
            title: Text('Item #$i'),
            subtitle: Text('Subtitle #$i'),
            trailing: const Icon(Icons.info_outline),
          ),
      ],
    );
  }
}

class SliverExpansionExampleSettings extends InheritedWidget {
  const SliverExpansionExampleSettings({
    super.key,
    required super.child,
    required this.pinnedHeader,
    required this.maintainState,
    required this.togglePinnedHeader,
    required this.toggleMaintainState,
  });

  final bool pinnedHeader;
  final bool maintainState;
  final VoidCallback togglePinnedHeader;
  final VoidCallback toggleMaintainState;

  static SliverExpansionExampleSettings of(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<SliverExpansionExampleSettings>();
    assert(settings != null, 'SliverExpansionExampleSettings not found.');
    return settings!;
  }

  @override
  bool updateShouldNotify(covariant SliverExpansionExampleSettings oldWidget) {
    return pinnedHeader != oldWidget.pinnedHeader ||
        maintainState != oldWidget.maintainState;
  }
}

enum _SettingsAction { togglePinnedHeader, toggleMaintainState }

class _SettingsMenuButton extends StatelessWidget {
  const _SettingsMenuButton();

  @override
  Widget build(BuildContext context) {
    final settings = SliverExpansionExampleSettings.of(context);

    return PopupMenuButton<_SettingsAction>(
      tooltip: 'Settings',
      onSelected: (action) {
        switch (action) {
          case _SettingsAction.togglePinnedHeader:
            settings.togglePinnedHeader();
            break;
          case _SettingsAction.toggleMaintainState:
            settings.toggleMaintainState();
            break;
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem<_SettingsAction>(
          value: _SettingsAction.togglePinnedHeader,
          checked: settings.pinnedHeader,
          child: const Text('Pinned header'),
        ),
        CheckedPopupMenuItem<_SettingsAction>(
          value: _SettingsAction.toggleMaintainState,
          checked: settings.maintainState,
          child: const Text('Maintain state'),
        ),
      ],
    );
  }
}
