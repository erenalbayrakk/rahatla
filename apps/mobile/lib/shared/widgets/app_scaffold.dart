import 'package:flutter/material.dart';

/// Ferah sayfa iskeleti — AppBar yok, özel header kullanılır.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(padding: padding, child: body),
      ),
    );
  }
}
