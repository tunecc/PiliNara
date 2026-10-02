import 'package:flutter/material.dart';

class RuleSection extends StatelessWidget {
  const RuleSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
  });
  final String title;
  final String? description;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, color: theme.colorScheme.primary), const SizedBox(width: 12)],
              Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
            ]),
            if (description != null) ...[const SizedBox(height: 6), Text(description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))],
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

InputDecoration ruleInputDecoration(BuildContext context, {String? label, String? hint, Widget? prefix, Widget? suffix}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label, hintText: hint, prefixIcon: prefix, suffixIcon: suffix,
    filled: true, fillColor: colors.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
  );
}
