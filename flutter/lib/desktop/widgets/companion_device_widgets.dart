import 'package:flutter/material.dart';
import '../../common/companion_theme.dart';

/// Presentation only: connection, selection and menu actions stay with the peer card.
class CompanionDeviceCard extends StatelessWidget {
  const CompanionDeviceCard(
      {super.key,
      required this.title,
      required this.id,
      required this.host,
      required this.note,
      required this.online,
      required this.statusLabel,
      required this.platform,
      required this.action,
      this.foregroundDecoration});

  final String title, id, host, note, statusLabel;
  final bool online;
  final Widget platform, action;
  final Decoration? foregroundDecoration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final statusColor = online
        ? (dark ? CompanionTheme.mint : CompanionTheme.mintDeep)
        : theme.hintColor;
    return Container(
      foregroundDecoration: foregroundDecoration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: .12)
                : theme.colorScheme.primary.withValues(alpha: .14)),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF3A2A55), Color(0xFF25203E)]
                : const [Color(0xFFFFF9FC), Color(0xFFF0F7FA)]),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .20 : .05),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  gradient: CompanionTheme.primaryGradient(dark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .22), width: .8),
                  boxShadow: CompanionTheme.glow(CompanionTheme.violet,
                      blur: 16, y: 5, alpha: .26)),
              child: platform),
          const SizedBox(width: 9),
          Expanded(
              child: Tooltip(
                  message: statusLabel,
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .12),
                          borderRadius: CompanionTheme.pill),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 6.5, color: statusColor),
                        const SizedBox(width: 5),
                        Flexible(
                            child: Text(statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor))),
                      ]),
                    ),
                  ]))),
          SizedBox.square(dimension: 32, child: Center(child: action)),
        ]),
        const SizedBox(height: 8),
        Expanded(
            child: SingleChildScrollView(
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
                message: title,
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .1,
                        height: 1.3))),
            if (title != id)
              Text(id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      letterSpacing: .3,
                      color: theme.hintColor)),
            if (host.isNotEmpty && host != title && host != id)
              Tooltip(
                  message: host,
                  child: Text(host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.hintColor))),
            if (note.isNotEmpty)
              Tooltip(
                  message: note,
                  child: Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: theme.hintColor))),
          ],
        ))),
      ]),
    );
  }
}

class CompanionDeviceSearch extends StatelessWidget {
  const CompanionDeviceSearch(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.onClose,
      required this.hint,
      required this.clearLabel,
      required this.closeLabel});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String hint, clearLabel, closeLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 180,
      child: Row(children: [
        Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: CompanionTheme.pill,
                  borderSide:
                      BorderSide(color: Theme.of(context).dividerColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: CompanionTheme.pill,
                  borderSide:
                      BorderSide(color: Theme.of(context).dividerColor)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      tooltip: clearLabel,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.backspace_outlined)),
            ),
          ),
        )),
        IconButton(
            tooltip: closeLabel,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18)),
      ]));
}

class CompanionNoSearchResults extends StatelessWidget {
  const CompanionNoSearchResults(
      {super.key,
      required this.query,
      required this.title,
      required this.clearLabel,
      required this.onClear});

  final String query, title, clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      CompanionTheme.violet.withValues(alpha: .18),
                      CompanionTheme.pink.withValues(alpha: .18)
                    ]),
                    boxShadow: CompanionTheme.glow(CompanionTheme.violet,
                        blur: 22, y: 8, alpha: .18)),
                child: Icon(Icons.search_off_rounded,
                    size: 30, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(query,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: Text(clearLabel)),
          ]),
        ),
      ));
}

class CompanionPublicServerHint extends StatelessWidget {
  const CompanionPublicServerHint(
      {super.key, required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                decoration: TextDecoration.underline, fontSize: 14)),
      );
}

class CompanionServiceStatusLabel extends StatelessWidget {
  const CompanionServiceStatusLabel(
      {super.key,
      required this.label,
      required this.message,
      required this.explanation});
  final String label, message, explanation;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '$label: $message\n$explanation',
        child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$label  ',
                  style: TextStyle(color: Theme.of(context).hintColor)),
              TextSpan(text: message),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13)),
      );
}
