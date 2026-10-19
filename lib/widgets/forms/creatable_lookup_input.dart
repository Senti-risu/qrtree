import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/word_capitalization.dart';

class CreatableLookupInput extends StatefulWidget {
  const CreatableLookupInput({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.onCreate,
    this.hintText = 'Type or select',
    this.enabled = true,
    this.errorText,
    this.disabledItems = const {},
  });
  final String label;
  final String? value, errorText;
  final List<String> items;
  final Set<String> disabledItems;
  final ValueChanged<String?> onChanged;
  final Future<String?> Function(String)? onCreate;
  final String hintText;
  final bool enabled;

  @override
  State<CreatableLookupInput> createState() => _CreatableLookupInputState();
}

class _CreatableLookupInputState extends State<CreatableLookupInput> {
  late final TextEditingController _controller;
  bool _busy = false;
  bool _syncing = false;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: capitalizeWords(widget.value ?? ''),
    )..addListener(_changed);
  }

  void _changed() {
    if (!_syncing && mounted) {
      _editing = true;
      setState(() => _error = null);
      if (widget.value != null &&
          _controller.text != capitalizeWords(widget.value!)) {
        widget.onChanged(null);
      }
    }
  }

  @override
  void didUpdateWidget(covariant CreatableLookupInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.enabled != widget.enabled) {
      _syncing = true;
      if (widget.value != null ||
          !_editing ||
          oldWidget.enabled != widget.enabled) {
        _controller.text = capitalizeWords(widget.value ?? '');
        _editing = false;
      }
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !widget.enabled || widget.onCreate == null) return;
    final name = capitalizeWords(
      _controller.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    );
    if (name.isEmpty || name.length > 100) {
      setState(() => _error = 'Use 1–100 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.onCreate!(name);
      if (!mounted || saved == null) return;
      _syncing = true;
      _controller.text = capitalizeWords(saved);
      _syncing = false;
      widget.onChanged(saved);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback:
                'Could not add this ${widget.label.toLowerCase()}. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _controller.text.trim();
    final canAdd =
        typed.isNotEmpty &&
        !widget.items.any(
          (item) => item.toLowerCase().trim() == typed.toLowerCase(),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<String>(
            controller: _controller,
            width: constraints.maxWidth,
            enabled: widget.enabled && !_busy,
            hintText: widget.hintText,
            requestFocusOnTap: true,
            enableFilter: true,
            enableSearch: true,
            menuHeight: 280,
            errorText: _error ?? widget.errorText,
            inputDecorationTheme: InputDecorationTheme(
              errorMaxLines: 3,
              filled: true,
              fillColor: widget.enabled && !_busy
                  ? AppColors.surface
                  : AppColors.surfaceDisabled,
            ),
            trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            selectedTrailingIcon: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.green,
            ),
            dropdownMenuEntries: widget.items
                .map(
                  (item) => DropdownMenuEntry<String>(
                    value: item,
                    label: capitalizeWords(item),
                    enabled: !widget.disabledItems.contains(item),
                  ),
                )
                .toList(),
            onSelected: (value) {
              if (value != null && !widget.disabledItems.contains(value)) {
                _editing = false;
                widget.onChanged(value);
              }
            },
          ),
        ),
        if (widget.onCreate != null && widget.enabled && (canAdd || _busy)) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_busy ? 'Adding…' : 'Add "$typed"', softWrap: true),
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
            ),
          ),
        ],
      ],
    );
  }
}
