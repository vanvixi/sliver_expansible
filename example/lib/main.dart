import 'package:flutter/material.dart';

void main() {
  runApp(const SliverExpansionExampleApp());
}

class SliverExpansionExampleApp extends StatelessWidget {
  const SliverExpansionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sliver Expansion Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Placeholder(),
    );
  }
}
