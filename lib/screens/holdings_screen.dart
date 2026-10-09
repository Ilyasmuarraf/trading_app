import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/holding.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import 'order_ticket_sheet.dart';
import 'theme.dart';

enum HoldingsSort { pnlDesc, symbolAsc, valueDesc }

final holdingsSortProvider =
    StateProvider<HoldingsSort>((ref) => HoldingsSort.pnlDesc);

class HoldingsScreen extends ConsumerWidget {
  const HoldingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final sort = ref.watch(holdingsSortProvider);
    final quotes = ref.watch(stockQuotesProvider);

    int currentValueOf(Holding h) => h.quantity * quotes[h.symbol]!.ltpPaise;
    int investedOf(Holding h) => h.quantity * h.avgCostPaise;
    int pnlOf(Holding h) => currentValueOf(h) - investedOf(h);

    final sorted = [...holdings];
    switch (sort) {
      case HoldingsSort.pnlDesc:
        sorted.sort((a, b) => pnlOf(b).compareTo(pnlOf(a)));
        break;
      case HoldingsSort.symbolAsc:
        sorted.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
      case HoldingsSort.valueDesc:
        sorted.sort((a, b) => currentValueOf(b).compareTo(currentValueOf(a)));
        break;
    }

    final totalInvested =
        holdings.fold<int>(0, (sum, h) => sum + investedOf(h));
    final totalValue = holdings.fold<int>(0, (sum, h) => sum + currentValueOf(h));
    final totalPnl = totalValue - totalInvested;
    final totalPnlPercent =
        totalInvested == 0 ? 0.0 : (totalPnl / totalInvested) * 100;
    final totalColor = totalPnl >= 0 ? AppColors.up : AppColors.down;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          PopupMenuButton<HoldingsSort>(
            tooltip: 'Sort holdings',
            initialValue: sort,
            onSelected: (s) =>
                ref.read(holdingsSortProvider.notifier).state = s,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: HoldingsSort.pnlDesc,
                child: Text('Sort by P&L'),
              ),
              PopupMenuItem(
                value: HoldingsSort.symbolAsc,
                child: Text('Sort by symbol'),
              ),
              PopupMenuItem(
                value: HoldingsSort.valueDesc,
                child: Text('Sort by value'),
              ),
            ],
          ),
        ],
      ),
      body: holdings.isEmpty
          ? const _EmptyPortfolio()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PortfolioHero(
                    invested: totalInvested,
                    value: totalValue,
                    pnl: totalPnl,
                    pnlPercent: totalPnlPercent,
                    pnlColor: totalColor,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          'Your positions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${holdings.length} stocks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  sliver: SliverList.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final holding = sorted[i];
                      return _HoldingTile(
                        key: ValueKey(holding.symbol),
                        holding: holding,
                        onTap: () => showOrderTicketSheet(
                          context,
                          symbol: holding.symbol,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({
    required this.invested,
    required this.value,
    required this.pnl,
    required this.pnlPercent,
    required this.pnlColor,
  });

  final int invested;
  final int value;
  final int pnl;
  final double pnlPercent;
  final Color pnlColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL PORTFOLIO VALUE',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value.toRupeeString(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                pnl >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: pnlColor,
                size: 19,
              ),
              const SizedBox(width: 4),
              Text(
                '${pnl.toSignedRupeeString()} (${pnlPercent.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: pnlColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Invested',
                  value: invested.toCompactRupeeString(),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Current',
                  value: value.toCompactRupeeString(),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Net P&L',
                  value: pnl.toCompactRupeeString(),
                  color: pnlColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HoldingTile extends ConsumerWidget {
  const _HoldingTile({
    super.key,
    required this.holding,
    required this.onTap,
  });

  final Holding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(stockQuoteProvider(holding.symbol));
    final currentValuePaise = holding.quantity * quote.ltpPaise;
    final investedPaise = holding.quantity * holding.avgCostPaise;
    final pnlPaise = currentValuePaise - investedPaise;
    final pnlPercent =
        investedPaise == 0 ? 0.0 : (pnlPaise / investedPaise) * 100;
    final color = pnlPaise >= 0 ? AppColors.up : AppColors.down;
    final stock = stockDefinition(holding.symbol);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF0F4FA),
                child: Text(
                  holding.symbol.substring(0, holding.symbol.length >= 2 ? 2 : holding.symbol.length),
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.symbol,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${holding.quantity} shares • Avg ${holding.avgCostPaise.toRupeeString()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currentValuePaise.toRupeeString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pnlPaise.toSignedRupeeString()} (${pnlPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.brand,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your portfolio is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              'Buy a stock from the Market tab to see your positions here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
