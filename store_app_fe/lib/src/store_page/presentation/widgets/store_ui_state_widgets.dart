import 'package:flutter/material.dart';

const _ink900 = Color(0xFF282321);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

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
      duration: const Duration(milliseconds: 2500),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2563EB),
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

