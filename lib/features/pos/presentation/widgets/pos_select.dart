import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class PosSelectOption<T> {
  const PosSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

class PosSelect<T> extends StatefulWidget {
  const PosSelect({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    required this.hintText,
    this.width,
    this.height = 32,
    this.borderRadius = 6,
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingIconBoxed = false,
    this.leadingIconBoxSize = 22,
    this.leadingIconSize = 13,
    this.enableSearch = true,
    this.minSearchChars = 0,
    this.validationText = 'Please enter 1 or more characters',
    this.searchHintText = 'بحث...',
    this.maxDropdownHeight = 0,
    this.autoDropdownHeight = true,
    this.dropdownItemExtent = 36,
    this.dropdownMinWidth = 160,
    this.dropdownWidth,
    this.dropdownHoverColor,
    this.dropdownSelectedColor,
    this.enabled = true,
  });

  final List<PosSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String hintText;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsets fieldPadding;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool leadingIconBoxed;
  final double leadingIconBoxSize;
  final double leadingIconSize;
  final bool enableSearch;
  final int minSearchChars;
  final String validationText;
  final String searchHintText;
  final double maxDropdownHeight;
  final bool autoDropdownHeight;
  final double dropdownItemExtent;
  final double dropdownMinWidth;
  final double? dropdownWidth;
  final Color? dropdownHoverColor;
  final Color? dropdownSelectedColor;
  final bool enabled;

  @override
  State<PosSelect<T>> createState() => _PosSelectState<T>();
}

class _PosSelectState<T> extends State<PosSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _fieldFocusNode = FocusNode();
  final FocusScopeNode _overlayFocusNode = FocusScopeNode();
  final ScrollController _scrollController = ScrollController();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  int _highlightIndex = -1;
  Size _fieldSize = Size.zero;
  List<PosSelectOption<T>> _filteredOptions = const [];

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant PosSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _filteredOptions = widget.options;
      _syncHighlightIndex();
      _requestOverlayRebuild();
    }
    if (oldWidget.enabled && !widget.enabled && _isOpen) {
      _closeOverlay();
    }
  }

  @override
  void deactivate() {
    _dismissOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _dismissOverlay();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _fieldFocusNode.dispose();
    _overlayFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterOptions();
    _requestOverlayRebuild();
  }

  void _requestOverlayRebuild() {
    if (_overlayEntry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _filterOptions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredOptions = widget.options;
    } else {
      _filteredOptions = widget.options.where((option) {
        final label = option.label.toLowerCase();
        final subtitle =
            _normalizedSubtitle(option.subtitle)?.toLowerCase() ?? '';
        return label.contains(query) || subtitle.contains(query);
      }).toList();
    }
    _highlightIndex = _filteredOptions.isEmpty ? -1 : 0;
  }

  String? _normalizedSubtitle(String? subtitle) {
    final value = subtitle?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  double _effectiveItemExtent(Iterable<PosSelectOption<T>> options) {
    final hasSubtitle = options.any(
      (option) => _normalizedSubtitle(option.subtitle) != null,
    );
    if (!hasSubtitle) return widget.dropdownItemExtent;
    return math.max(widget.dropdownItemExtent, 52);
  }

  void _syncHighlightIndex() {
    if (widget.value == null) {
      _highlightIndex = _filteredOptions.isEmpty ? -1 : 0;
      return;
    }
    final index = _filteredOptions.indexWhere(
      (option) => option.value == widget.value,
    );
    _highlightIndex = index >= 0 ? index : (_filteredOptions.isEmpty ? -1 : 0);
  }

  void _toggleOverlay() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    if (_isOpen) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box == null || !box.hasSize || overlay == null) return;

    _fieldSize = box.size;
    if (_fieldSize.isEmpty ||
        !_fieldSize.width.isFinite ||
        !_fieldSize.height.isFinite) {
      return;
    }

    _searchController.clear();
    _filteredOptions = widget.options;
    _syncHighlightIndex();
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isOpen) return;
      _overlayFocusNode.requestFocus();
    });
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _dismissOverlay(notify: true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _dismissOverlay({bool notify = false}) {
    if (_overlayEntry == null && !_isOpen) return;
    _removeOverlay();
    if (notify && mounted) {
      setState(() => _isOpen = false);
    } else {
      _isOpen = false;
    }
  }

  void _onOptionSelected(PosSelectOption<T> option) {
    widget.onChanged?.call(option.value);
    _closeOverlay();
  }

  void _moveHighlight(int delta) {
    if (_filteredOptions.isEmpty) return;
    var next = _highlightIndex + delta;
    if (next < 0) next = 0;
    if (next >= _filteredOptions.length) next = _filteredOptions.length - 1;
    if (next != _highlightIndex) {
      setState(() => _highlightIndex = next);
      _scrollToHighlight();
    }
  }

  void _scrollToHighlight() {
    if (_highlightIndex < 0) return;
    final itemExtent = _effectiveItemExtent(_filteredOptions);
    final offset = _highlightIndex * itemExtent;
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _openOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleOverlayKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closeOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_highlightIndex >= 0 && _highlightIndex < _filteredOptions.length) {
        _onOptionSelected(_filteredOptions[_highlightIndex]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  double _resolveDropdownMaxHeight({
    required int optionCount,
    required bool showValidation,
    required bool showEmpty,
    required double itemExtent,
  }) {
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final maxAllowedHeight = screenHeight * 0.4; // أقصى حد 40% من ارتفاع الشاشة

    if (!widget.autoDropdownHeight) {
      if (widget.maxDropdownHeight > 0) {
        return math.min(widget.maxDropdownHeight, maxAllowedHeight);
      }
      return math.min(itemExtent * optionCount, maxAllowedHeight);
    }

    final listHeight = itemExtent * optionCount;
    final searchHeight = widget.enableSearch
        ? (44.0 + (AppSpacing.xs * 2))
        : 0.0;
    final statusHeight = (showValidation || showEmpty)
        ? (32.0 + (AppSpacing.xs * 2))
        : 0.0;
    var calculated = listHeight + searchHeight + statusHeight + AppSpacing.sm;

    if (calculated <= 0) {
      calculated = itemExtent + searchHeight + statusHeight;
    }

    final finalMax = widget.maxDropdownHeight > 0
        ? math.min(widget.maxDropdownHeight, maxAllowedHeight)
        : maxAllowedHeight;

    return math.min(calculated, finalMax);
  }

  OverlayEntry _createOverlayEntry() {
    final minWidth = widget.width ?? _fieldSize.width;
    final direction = Directionality.of(context);
    final hoverColor = widget.dropdownHoverColor ?? AppColors.selectHover;
    final selectedColor =
        widget.dropdownSelectedColor ?? AppColors.selectSelected;

    return OverlayEntry(
      builder: (context) {
        if (!mounted) {
          return const SizedBox.shrink();
        }
        final queryLength = _searchController.text.trim().length;
        final showValidation =
            widget.enableSearch &&
            widget.minSearchChars > 0 &&
            queryLength < widget.minSearchChars;
        final visibleOptions = showValidation
            ? <PosSelectOption<T>>[]
            : _filteredOptions;
        final showEmpty = !showValidation && visibleOptions.isEmpty;
        final itemExtent = _effectiveItemExtent(visibleOptions);
        final maxHeight = _resolveDropdownMaxHeight(
          optionCount: visibleOptions.length,
          showValidation: showValidation,
          showEmpty: showEmpty,
          itemExtent: itemExtent,
        );
        final view = View.of(this.context);
        final screenWidth = view.physicalSize.width / view.devicePixelRatio;
        final requestedWidth =
            widget.dropdownWidth ?? math.max(minWidth, widget.dropdownMinWidth);
        final overlayWidth = math.min(
          requestedWidth,
          math.max(120.0, screenWidth - 16),
        );
        final fieldBox = this.context.findRenderObject() as RenderBox?;
        final fieldOffset = fieldBox?.localToGlobal(Offset.zero) ?? Offset.zero;
        final baseDx = direction == TextDirection.rtl
            ? _fieldSize.width - overlayWidth
            : 0.0;
        final minDx = 8.0 - fieldOffset.dx;
        final maxDx = screenWidth - overlayWidth - fieldOffset.dx - 8.0;
        final resolvedDx = maxDx < minDx ? minDx : baseDx.clamp(minDx, maxDx);
        final followerOffset = Offset(
          resolvedDx,
          widget.height + AppSpacing.xs,
        );

        return Directionality(
          textDirection: direction,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeOverlay,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: followerOffset,
                child: Material(
                  color: Colors.transparent,
                  child: FocusScope(
                    node: _overlayFocusNode,
                    onKeyEvent: _handleOverlayKey,
                    child: Container(
                      width: overlayWidth,
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius,
                        ),
                        border: Border.all(color: AppColors.fieldBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.enableSearch)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    hintText: widget.searchHintText,
                                    hintStyle: AppTextStyles.selectHint,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: AppColors.fieldBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: AppColors.fieldBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: AppColors.borderBlue,
                                      ),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  style: AppTextStyles.selectText,
                                ),
                              ),
                            ),
                          if (showValidation)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  widget.validationText,
                                  style: AppTextStyles.selectValidation,
                                ),
                              ),
                            )
                          else if (showEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'لا توجد نتائج',
                                  style: AppTextStyles.selectHint,
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: visibleOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = visibleOptions[index];
                                    final subtitle = _normalizedSubtitle(
                                      option.subtitle,
                                    );
                                    final isHighlighted =
                                        index == _highlightIndex;
                                    final isSelected =
                                        widget.value != null &&
                                        widget.value == option.value;

                                    return InkWell(
                                      onTap: () => _onOptionSelected(option),
                                      onHover: (hover) {
                                        if (hover) {
                                          setState(
                                            () => _highlightIndex = index,
                                          );
                                        }
                                      },
                                      child: Container(
                                        color: isHighlighted
                                            ? hoverColor
                                            : isSelected
                                            ? selectedColor
                                            : Colors.transparent,
                                        constraints: BoxConstraints(
                                          minHeight: itemExtent,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: subtitle == null ? 8 : 6,
                                        ),
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          textDirection: ui.TextDirection.rtl,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    option.label,
                                                    style: AppTextStyles
                                                        .selectText,
                                                    textAlign: TextAlign.right,
                                                    textDirection:
                                                        ui.TextDirection.rtl,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (subtitle != null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      subtitle,
                                                      style: AppTextStyles
                                                          .selectHint
                                                          .copyWith(
                                                            fontSize: 10,
                                                          ),
                                                      textAlign:
                                                          TextAlign.right,
                                                      textDirection:
                                                          ui.TextDirection.rtl,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: AppColors.borderBlue,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    if (widget.value != null && widget.options.isNotEmpty) {
      final match = widget.options
          .where((option) => option.value == widget.value)
          .toList();
      if (match.isNotEmpty) {
        selectedLabel = match.first.label;
      }
    }

    final textStyle = selectedLabel == null
        ? AppTextStyles.selectHint
        : AppTextStyles.selectText;
    final borderColor = _isOpen ? AppColors.borderBlue : AppColors.fieldBorder;
    final borderRadius = BorderRadius.circular(widget.borderRadius);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _fieldFocusNode,
        onKeyEvent: _handleFieldKey,
        child: GestureDetector(
          onTap: _toggleOverlay,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.9,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.fieldPadding,
              decoration: BoxDecoration(
                color: AppColors.fieldBackground,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                textDirection: Directionality.of(context),
                children: [
                  if (widget.leadingIcon != null) ...[
                    if (widget.leadingIconBoxed)
                      Container(
                        width: widget.leadingIconBoxSize,
                        height: widget.leadingIconBoxSize,
                        decoration: BoxDecoration(
                          color: AppColors.fieldBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        child: Icon(
                          widget.leadingIcon,
                          size: widget.leadingIconSize,
                          color:
                              widget.leadingIconColor ??
                              AppColors.textSecondary,
                        ),
                      )
                    else
                      Icon(
                        widget.leadingIcon,
                        size: widget.leadingIconSize,
                        color:
                            widget.leadingIconColor ?? AppColors.textSecondary,
                      ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      selectedLabel ?? widget.hintText,
                      style: textStyle,
                      textAlign: TextAlign.right,
                      textDirection: ui.TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 120),
                    turns: _isOpen ? 0.5 : 0,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PosSelectField<T> extends StatelessWidget {
  const PosSelectField({
    super.key,
    required this.label,
    required this.hintText,
    required this.options,
    this.value,
    this.onChanged,
    this.width,
    this.height = 44,
    this.borderRadius = 12,
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingIconBoxed = false,
    this.leadingIconBoxSize = 22,
    this.leadingIconSize = 16,
    this.enableSearch = true,
    this.minSearchChars = 0,
    this.dropdownItemExtent = 36,
    this.maxDropdownHeight = 0,
    this.dropdownMinWidth = 160,
    this.dropdownWidth,
    this.dropdownHoverColor,
    this.dropdownSelectedColor,
    this.enabled = true,
    this.labelSpacing = AppSpacing.xs,
  });

  final String label;
  final String hintText;
  final List<PosSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsets fieldPadding;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool leadingIconBoxed;
  final double leadingIconBoxSize;
  final double leadingIconSize;
  final bool enableSearch;
  final int minSearchChars;
  final double dropdownItemExtent;
  final double maxDropdownHeight;
  final double dropdownMinWidth;
  final double? dropdownWidth;
  final Color? dropdownHoverColor;
  final Color? dropdownSelectedColor;
  final bool enabled;
  final double labelSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.fieldText, textAlign: TextAlign.right),
        SizedBox(height: labelSpacing),
        PosSelect<T>(
          options: options,
          value: value,
          onChanged: onChanged,
          hintText: hintText,
          width: width,
          height: height,
          borderRadius: borderRadius,
          fieldPadding: fieldPadding,
          leadingIcon: leadingIcon,
          leadingIconColor: leadingIconColor,
          leadingIconBoxed: leadingIconBoxed,
          leadingIconBoxSize: leadingIconBoxSize,
          leadingIconSize: leadingIconSize,
          enableSearch: enableSearch,
          minSearchChars: minSearchChars,
          dropdownItemExtent: dropdownItemExtent,
          maxDropdownHeight: maxDropdownHeight,
          dropdownMinWidth: dropdownMinWidth,
          dropdownWidth: dropdownWidth,
          dropdownHoverColor: dropdownHoverColor,
          dropdownSelectedColor: dropdownSelectedColor,
          enabled: enabled,
        ),
      ],
    );
  }
}
