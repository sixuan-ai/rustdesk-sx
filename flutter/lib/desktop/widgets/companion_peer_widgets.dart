import 'package:flutter/material.dart';

class CompanionPeerTabLabel extends StatelessWidget {
  const CompanionPeerTabLabel(
      {super.key,
      required this.icon,
      required this.label,
      required this.selected,
      required this.showLabel,
      required this.labelWidth,
      required this.color});

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final double labelWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        selected: selected,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            if (showLabel) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelWidth),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400)),
              ),
            ],
          ]),
        ),
      );
}

class CompanionPeerEmptyState extends StatelessWidget {
  const CompanionPeerEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: .09)),
                child: Icon(icon, size: 26, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: .7))),
          ]),
        ),
      ),
    );
  }
}
