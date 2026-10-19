import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../controllers/store_items_controller.dart';
import '../../../domains/models/item_rate_history_model.dart';
import '../../../domains/models/store_items_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFFA89F91);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentGreen = Color(0xFF10B981);
const _accentRed = Color(0xFFEF4444);

void showItemRateHistorySheet(
  BuildContext context, {
  required StoreItemsModel item,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    constraints: BoxConstraints(
      maxWidth: screenWidth >= 800 ? 760 : (screenWidth >= 600 ? screenWidth * 0.94 : double.infinity),
    ),
    builder: (_) => ItemRateHistorySheet(item: item),
  );
}

class ItemRateHistorySheet extends ConsumerWidget {
  const ItemRateHistorySheet({super.key, required this.item});

  final StoreItemsModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateHistoryAsync = ref.watch(itemRateHistoryProvider(item.id));
    final unitLabel = item.unit.trim().isNotEmpty ? item.unit.trim() : 'unit';

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.currency_rupee_rounded,
                          color: Color(0xFF2E7D32),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _stroke),
                                ),
                                child: Text(
                                  item.itemCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _ink900,
                                  ),
                                ),
                              ),
                              if (item.categoryLabel.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.categoryLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _ink600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink700),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: _stroke),

              // Content Body
              Flexible(
                child: rateHistoryAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _accentRed,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to load rate transactions',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: _ink600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => ref.invalidate(itemRateHistoryProvider(item.id)),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: _ink900),
                          label: const Text('Try Again'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink900,
                            iconColor: _ink900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (history) {
                    final entries = history.rateHistory;
                    final stats = history.stats;
                    final latestRate = history.latestRate > 0
                        ? history.latestRate
                        : (item.latestPurchasePrice > 0 ? item.latestPurchasePrice : 0.0);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Current / Latest Rate Prominent Card
                          _buildLatestRateCard(
                            latestRate: latestRate,
                            unitLabel: unitLabel,
                            stats: stats,
                            entries: entries,
                          ),
                          const SizedBox(height: 14),

                          // 2. Metrics KPI summary tiles
                          if (entries.isNotEmpty) ...[
                            _buildKpiSummaryRow(stats: stats, unitLabel: unitLabel),
                            const SizedBox(height: 18),
                          ],

                          // 3. Transactions List Header
                          Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                size: 17,
                                color: _ink900,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Refill & Rate Transactions',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _stroke),
                                ),
                                child: Text(
                                  '${entries.length} recorded',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 4. Timeline list or Empty state
                          if (entries.isEmpty)
                            _buildEmptyState(latestRate, unitLabel)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: entries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _RateTransactionCard(
                                  entry: entries[index],
                                  unitLabel: unitLabel,
                                  isLatest: index == 0,
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestRateCard({
    required double latestRate,
    required String unitLabel,
    required ItemRateStats stats,
    required List<ItemRateEntry> entries,
  }) {
    final hasDiff = entries.length > 1;
    final diffAmount = stats.rateChange;
    final isIncrease = diffAmount > 0;
    final isDecrease = diffAmount < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F8F5), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LATEST PURCHASE / REFILL RATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E7D32),
                  letterSpacing: 0.6,
                ),
              ),
              if (hasDiff)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isIncrease
                        ? const Color(0xFFFFEBEE)
                        : (isDecrease ? const Color(0xFFE8F5E9) : _surfaceAlt),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isIncrease
                          ? const Color(0xFFFFCDD2)
                          : (isDecrease ? const Color(0xFFA5D6A7) : _stroke),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIncrease
                            ? Icons.trending_up_rounded
                            : (isDecrease ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                        size: 13,
                        color: isIncrease
                            ? _accentRed
                            : (isDecrease ? _accentGreen : _ink700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isIncrease
                            ? '+₹${diffAmount.toStringAsFixed(2)} vs previous'
                            : (isDecrease
                                ? '-₹${diffAmount.abs().toStringAsFixed(2)} vs previous'
                                : 'Same as previous'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isIncrease
                              ? _accentRed
                              : (isDecrease ? _accentGreen : _ink700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${latestRate.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _ink900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ $unitLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow({
    required ItemRateStats stats,
    required String unitLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: 'Previous Rate',
            value: stats.previousRate > 0 ? '₹${stats.previousRate.toStringAsFixed(2)}' : '-',
            icon: Icons.history_rounded,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiTile(
            label: 'Lowest Rate',
            value: stats.minRate > 0 ? '₹${stats.minRate.toStringAsFixed(2)}' : '-',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiTile(
            label: 'Highest Rate',
            value: stats.maxRate > 0 ? '₹${stats.maxRate.toStringAsFixed(2)}' : '-',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiTile(
            label: 'Avg Rate',
            value: stats.avgRate > 0 ? '₹${stats.avgRate.toStringAsFixed(2)}' : '-',
            icon: Icons.calculate_outlined,
            color: const Color(0xFF06B6D4),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(double latestRate, String unitLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: _ink500,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Refill Transactions Logged Yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _ink900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            latestRate > 0
                ? 'Registered item baseline is ₹${latestRate.toStringAsFixed(2)} / $unitLabel. Future refill receipts will record rate variance history automatically.'
                : 'Rates will be automatically tracked whenever stock is received or refilled through Store Receive or GRN.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _ink600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _ink600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTransactionCard extends StatelessWidget {
  const _RateTransactionCard({
    required this.entry,
    required this.unitLabel,
    this.isLatest = false,
  });

  final ItemRateEntry entry;
  final String unitLabel;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final dateStr = entry.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(entry.date!.toLocal())
        : 'Date unavailable';

    final isIncrease = entry.diffAmount > 0;
    final isDecrease = entry.diffAmount < 0;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest ? const Color(0xFFA5D6A7) : _stroke,
          width: isLatest ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date & Voucher Chip + Latest badge
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: _ink600,
              ),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ink600,
                ),
              ),
              const Spacer(),
              if (isLatest) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Text(
                    'LATEST',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _stroke),
                ),
                child: Text(
                  entry.voucherNo,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _ink900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Rate + Qty + Total Value
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              // Big Rate Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Text(
                  '₹${entry.rate.toStringAsFixed(2)} / $unitLabel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),

              // Quantity Received
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Received: +${entry.qty} $unitLabel',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _ink900,
                    ),
                  ),
                  if (entry.totalAmount > 0)
                    Text(
                      'Total: ₹${entry.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _ink600,
                      ),
                    ),
                ],
              ),

              // Difference badge vs prior refill
              if (entry.diffFromPrevious.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isIncrease
                        ? const Color(0xFFFFEBEE)
                        : (isDecrease ? const Color(0xFFE8F5E9) : _surfaceAlt),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.diffFromPrevious,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isIncrease
                          ? _accentRed
                          : (isDecrease ? _accentGreen : _ink700),
                    ),
                  ),
                ),
            ],
          ),

          // Row 3: Meta details (receivedBy & remark)
          if (entry.receivedBy.isNotEmpty || entry.remarks.isNotEmpty || entry.grnNo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (entry.receivedBy.isNotEmpty && entry.receivedBy != '-')
                  Text(
                    'Receiver: ${entry.receivedBy}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: _ink700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (entry.grnNo.isNotEmpty)
                  Text(
                    'GRN: ${entry.grnNo}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: _ink700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (entry.remarks.isNotEmpty)
                  Text(
                    'Note: ${entry.remarks}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: _ink600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
