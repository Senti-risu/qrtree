import 'package:flutter/material.dart';

import '../utils/search_match.dart';

/// Search with selectable, word-prefix suggestions from accessible records.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.onChanged,
    required this.decoration,
    this.textInputAction = TextInputAction.search,
  });

  final TextEditingController controller;
  final Iterable<String> suggestions;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextInputAction textInputAction;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text;
        if (value.text.trim().isEmpty) return const Iterable<String>.empty();
        final seen = <String>{};
        return widget.suggestions
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty && seen.add(value.toLowerCase()))
            .where((value) => matchesWordPrefixes([value], query))
            .take(8)
            .toList();
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focus, submit) => TextField(
        controller: controller,
        focusNode: focus,
        onChanged: widget.onChanged,
        textInputAction: widget.textInputAction,
        onSubmitted: (_) => submit(),
        decoration: widget.decoration.copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.decoration.suffixIcon != null)
                widget.decoration.suffixIcon!,
              IconButton(
                tooltip: 'Show Search Suggestions',
                onPressed: () {
                  _focusNode.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _focusNode.requestFocus();
                  });
                },
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ],
          ),
        ),
      ),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: constraints.maxWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    selected:
                        AutocompleteHighlightedOption.of(context) == index,
                    title: Text(option),
                    onTap: () => select(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
