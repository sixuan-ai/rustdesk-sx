import 'package:flutter/material.dart';

/// A real editable field gives GTK/Flutter ownership of IME preedit and commit.
/// It lives outside the remote raw-key focus scope to avoid sending pinyin twice.
class WaylandTextInput extends StatefulWidget {
  const WaylandTextInput({
    super.key,
    required this.sendText,
    required this.onEditing,
  });

  final Future<void> Function(String) sendText;
  final ValueChanged<bool> onEditing;

  @override
  State<WaylandTextInput> createState() => _WaylandTextInputState();
}

class _WaylandTextInputState extends State<WaylandTextInput> {
  final _controller = TextEditingController();
  bool _open = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  bool get _composing =>
      _controller.value.composing.isValid &&
      !_controller.value.composing.isCollapsed;

  Future<void> _send() async {
    if (_sending || _composing || _controller.text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.sendText(_controller.text);
      if (mounted) _controller.clear();
    } catch (_) {
      if (mounted) setState(() => _error = '发送失败，请检查连接后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return FilledButton.tonalIcon(
        icon: const Icon(Icons.translate, size: 18),
        label: const Text('中文输入'),
        onPressed: () {
          widget.onEditing(true);
          setState(() => _open = true);
        },
      );
    }
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _controller,
              autofocus: true,
              readOnly: _sending,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '中文输入',
                hintText: '在本机选好候选词，再发送到远端',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: _sending
                    ? null
                    : () {
                        widget.onEditing(false);
                        setState(() => _open = false);
                      },
                child: const Text('收起'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending || _composing || _controller.text.isEmpty
                    ? null
                    : _send,
                child: Text(_sending ? '发送中…' : '发送到远端'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
