import 'dart:async';
import 'package:flutter/material.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

/// Standardized smooth Store loading spinner matching the app's original ink color (#282321).
class StoreLoadingWidget extends StatelessWidget {
  const StoreLoadingWidget({
    super.key,
    this.message,
    this.size = 28.0,
    this.strokeWidth = 2.5,
  });

  final String? message;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: const AlwaysStoppedAnimation<Color>(_ink900),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: const TextStyle(
                  color: _ink700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized error view with user-friendly text and retry action.
class StoreErrorView extends StatelessWidget {
  const StoreErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.message,
  });

  final Object error;
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final displayMsg = message ?? 'Unable to load store data. Please try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Technical error details: ${error.toString().split('\n').first}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standardized empty state view supporting search query clearing.
class StoreEmptyStateWidget extends StatelessWidget {
  const StoreEmptyStateWidget({
    super.key,
    required this.message,
    this.searchQuery = '',
    this.onClearSearch,
    this.icon = Icons.inbox_rounded,
  });

  final String message;
  final String searchQuery;
  final VoidCallback? onClearSearch;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isSearching = searchQuery.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : icon,
              size: 48,
              color: _ink600,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'No matching results for "$searchQuery"'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (isSearching && onClearSearch != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded, size: 16, color: _ink900),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink900,
                  iconColor: _ink900,
                  side: const BorderSide(color: _stroke),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Visual stock status badge:
/// - Available <= 0 -> OUT OF STOCK (Red)
/// - Available < 5 -> LOW STOCK (Amber)
/// - Available >= 5 -> IN STOCK (Green)
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({
    super.key,
    required this.availableQty,
    this.minStock,
    this.isIndentReady = false,
    this.compact = false,
  });

  final num availableQty;
  final num? minStock;
  final bool isIndentReady;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late Color border;
    late String label;
    late IconData icon;

    final threshold = (minStock != null && minStock! > 0) ? minStock! : 5;

    if (isIndentReady) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      border = const Color(0xFFFFCC80);
      label = 'INDENT-READY (EOD)';
      icon = Icons.nightlight_round;
    } else if (availableQty <= 0) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      border = const Color(0xFFFFCDD2);
      label = 'OUT OF STOCK';
      icon = Icons.cancel_outlined;
    } else if (availableQty <= threshold) {
      bg = const Color(0xFFFFF8E1);
      fg = const Color(0xFFF57F17);
      border = const Color(0xFFFFECB3);
      label = 'LOW STOCK ($availableQty)';
      icon = Icons.warning_amber_rounded;
    } else {
      bg = const Color(0xE8E8F5E9);
      fg = const Color(0xFF2E7D32);
      border = const Color(0xFFC8E6C9);
      label = 'IN STOCK';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized mutation feedback SnackBar with checkmark and 2.5s duration.
void showStoreSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor: isError ? Colors.red.shade700 : _ink900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Standardized canonical date/time formatter: DD/MM/YYYY hh:mm AM/PM
String formatStoreDateTime(dynamic v) {
  if (v == null) return '—';
  DateTime? d;
  if (v is DateTime) {
    d = v;
  } else if (v is int) {
    if (v > 1000000000000) {
      d = DateTime.fromMillisecondsSinceEpoch(v);
    } else {
      d = DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
  } else if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return '—';
    final asInt = int.tryParse(s);
    if (asInt != null) {
      return formatStoreDateTime(asInt);
    }
    d = DateTime.tryParse(s);
  }
  if (d == null) return '—';
  final local = d.toLocal();

  String two(int n) => n.toString().padLeft(2, '0');
  final day = two(local.day);
  final month = two(local.month);
  final year = local.year.toString();

  final hour12 = (local.hour % 12 == 0) ? 12 : (local.hour % 12);
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  final hh = two(hour12);
  final mm = two(local.minute);

  return '$day/$month/$year $hh:$mm $ampm';
}

/// Neutral transaction quantity pill to separate quantity display from StockStatusChip
class StoreQtyPill extends StatelessWidget {
  const StoreQtyPill({
    super.key,
    required this.quantity,
    this.label,
    this.compact = false,
  });

  final num quantity;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final qStr = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
    final text = label != null && label!.isNotEmpty ? '$label: $qStr' : qStr;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.numbers_rounded, size: 14, color: _ink600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11.5 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized card container for Store module views.
class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 12),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}

/// Standardized "Load More" button with item icon and active loading indicator.
class StoreLoadMoreButton extends StatefulWidget {
  const StoreLoadMoreButton({
    super.key,
    required this.onPressed,
    this.label = 'Load more',
    this.icon = Icons.inventory_2_rounded,
    this.isLoading = false,
  });

  final FutureOr<void> Function()? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  State<StoreLoadMoreButton> createState() => _StoreLoadMoreButtonState();
}

class _StoreLoadMoreButtonState extends State<StoreLoadMoreButton> {
  bool _internalLoading = false;

  Future<void> _handleTap() async {
    if (widget.isLoading || _internalLoading || widget.onPressed == null) return;
    setState(() => _internalLoading = true);
    try {
      final res = widget.onPressed!();
      if (res is Future) {
        await res;
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      if (mounted) {
        setState(() => _internalLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.isLoading || _internalLoading;
    final displayIcon = widget.icon ?? Icons.inventory_2_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : _handleTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _ink900,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  displayIcon,
                  size: 16,
                  color: Colors.white,
                ),
              const SizedBox(width: 5),
              Text(
                loading ? 'Loading...' : widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized pagination status bar matching the Items page style.
/// Fully responsive and mobile-optimized (prevents RenderFlex overflow on small screens).
class StorePaginationBar extends StatelessWidget {
  const StorePaginationBar({
    super.key,
    required this.currentCount,
    required this.totalCount,
    this.itemLabel,
    this.canLoadMore = false,
    this.onLoadMore,
    this.icon = Icons.inventory_2_rounded,
    this.isLoading = false,
    this.maxWidth = 980,
  });

  final int currentCount;
  final int totalCount;
  final String? itemLabel;
  final bool canLoadMore;
  final FutureOr<void> Function()? onLoadMore;
  final IconData? icon;
  final bool isLoading;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final suffix = (itemLabel != null && itemLabel!.trim().isNotEmpty)
        ? ' ${itemLabel!.trim()}'
        : '';
    final countText = 'Showing $currentCount of $totalCount$suffix';

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  countText,
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canLoadMore && onLoadMore != null) ...[
                const SizedBox(width: 8),
                StoreLoadMoreButton(
                  onPressed: onLoadMore,
                  icon: icon,
                  isLoading: isLoading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A lightweight, mobile-optimized, expandable reason/remarks widget.
/// Truncates long reasons to 2 lines with a clean "Show more" / "Show less" toggle.
/// Highly optimized as a self-contained StatefulWidget so toggling does not trigger parent rebuilds.
class StoreDynamicReasonBox extends StatefulWidget {
  const StoreDynamicReasonBox({
    super.key,
    required this.reason,
    this.prefix = 'Reason: ',
    this.thresholdLength = 65,
    this.collapsedMaxLines = 2,
    this.margin,
    this.backgroundColor,
    this.borderColor,
  });

  final String reason;
  final String prefix;
  final int thresholdLength;
  final int collapsedMaxLines;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  State<StoreDynamicReasonBox> createState() => _StoreDynamicReasonBoxState();
}

class _StoreDynamicReasonBoxState extends State<StoreDynamicReasonBox> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cleanReason = widget.reason.trim();
    if (cleanReason.isEmpty) return const SizedBox.shrink();

    final isLong = cleanReason.length > widget.thresholdLength ||
        cleanReason.contains('\n');

    final bg = widget.backgroundColor ?? const Color(0xFFFBF9F6);
    final border = widget.borderColor ?? _stroke.withValues(alpha: 0.8);

    return Container(
      width: double.infinity,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLong
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 6),
                      child: Icon(
                        Icons.comment_outlined,
                        size: 13,
                        color: _ink600,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _ink700,
                            height: 1.35,
                          ),
                          children: [
                            if (widget.prefix.isNotEmpty)
                              TextSpan(
                                text: widget.prefix,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.normal,
                                  color: _ink900,
                                ),
                              ),
                            TextSpan(
                              text: cleanReason,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        maxLines: _isExpanded ? null : widget.collapsedMaxLines,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isLong) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _isExpanded ? 'Show less' : 'Show more',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _ink900,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: _ink900,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

