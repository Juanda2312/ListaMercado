import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.radius = 18});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
