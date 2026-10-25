import 'package:flutter/material.dart';

import '../../common/companion_theme.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
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
      this.message = '',
      this.detail,
      this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? detail;
  final Widget? action;

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
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: .18),
                          CompanionTheme.pink.withValues(alpha: .16)
                        ]),
                    border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: .18)),
                    boxShadow: CompanionTheme.glow(CompanionTheme.violet,
                        blur: 26, y: 10, alpha: .20)),
                child: Icon(icon, size: 28, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: .7))),
            ],
            if (detail != null) ...[
              const SizedBox(height: 12),
              detail!,
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ]),
        ),
      ),
    );
  }
}

class CompanionErrorBanner extends StatelessWidget {
  const CompanionErrorBanner(
      {super.key,
      required this.message,
      this.retryLabel,
      this.onRetry,
      this.closeLabel,
      required this.onClose});

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = CompanionTheme.isDark(context);
    final error = theme.colorScheme.error;
    final textColor = theme.textTheme.bodyMedium?.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CompanionTheme.controlRadius),
          color: error.withValues(alpha: dark ? .16 : .07),
          border: Border.all(color: error.withValues(alpha: dark ? .34 : .20))),
      child: Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: error.withValues(alpha: dark ? .22 : .12)),
            child: Icon(Icons.error_outline_rounded, size: 18, color: error)),
        const SizedBox(width: 10),
        Expanded(
            child: SelectableText(message,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: textColor?.withValues(alpha: .92)))),
        if (retryLabel != null && onRetry != null)
          TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                  foregroundColor: error,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              child: Text(retryLabel!)),
        IconButton(
            onPressed: onClose,
            tooltip: closeLabel,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            color: textColor?.withValues(alpha: .65),
            icon: const Icon(Icons.close_rounded)),
      ]),
    );
  }
}
