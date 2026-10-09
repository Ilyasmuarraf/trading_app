import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../providers/market_provider.dart';
import '../providers/watchlist_provider.dart';
import 'order_ticket_sheet.dart';
import 'theme.dart';

final marketSearchProvider = StateProvider<String>((ref) => '');

class LiveMarketScreen extends ConsumerWidget {
  const LiveMarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(marketSearchProvider).trim().toLowerCase();
    final stocks = kStockUniverse.where((stock) {
      if (search.isEmpty) return true;
      return stock.symbol.toLowerCase().contains(search) ||
          stock.name.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('TradeX'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          const _MarketHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (value) =>
                  ref.read(marketSearchProvider.notifier).state = value,
              decoration: const InputDecoration(
                hintText: 'Search stocks, symbols...',
                prefixIcon: Icon(Icons.search_rounded, size: 21),
                suffixIcon: Icon(Icons.tune_rounded, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'Market',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${stocks.length} stocks',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: stocks.isEmpty
                ? const Center(child: Text('No stocks match your search.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      final stock = stocks[index];
                      return LivePriceTile(
                        key: ValueKey(stock.symbol),
                        symbol: stock.symbol,
                        onTap: () => showOrderTicketSheet(
                          context,
                          symbol: stock.symbol,
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

class _MarketHero extends ConsumerWidget {
  const _MarketHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(stockQuotesProvider);
    final totalMove = kStockSymbols.fold<int>(
      0,
      (sum, symbol) => sum + quotes[symbol]!.changePaise,
    );
    final positive = totalMove >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4F91), Color(0xFF387ED1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18387ED1),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MARKET LIVE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'NSE • Real-time simulation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            totalMove.toSignedRupeeString(),
            style: TextStyle(
              color: positive ? const Color(0xFFB9F5DD) : const Color(0xFFFFC7C7),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class LivePriceTile extends ConsumerStatefulWidget {
  const LivePriceTile({
    super.key,
    required this.symbol,
    this.onTap,
  });

  final String symbol;
  final VoidCallback? onTap;

  @override
  ConsumerState<LivePriceTile> createState() => _LivePriceTileState();
}

class _LivePriceTileState extends ConsumerState<LivePriceTile> {
  int? _previousLtp;
  FlashDirection? _flash;

  void _handleUpdate(StockQuote quote) {
    if (_previousLtp != null && quote.ltpPaise != _previousLtp) {
      final direction =
          quote.ltpPaise > _previousLtp! ? FlashDirection.up : FlashDirection.down;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _flash = direction);
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) setState(() => _flash = null);
        });
      });
    }
    _previousLtp = quote.ltpPaise;
  }

  Future<void> _toggleStar() async {
    final added = await ref
        .read(watchlistsProvider.notifier)
        .toggleQuickWatchlist(widget.symbol);
    if (!mounted) return;
    final name = ref.read(watchlistsProvider.notifier).quickWatchlistName();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '${widget.symbol} added to $name'
                : '${widget.symbol} removed from $name',
          ),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          width: 340,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(stockQuoteProvider(widget.symbol));
    final isStarred = ref.watch(quickWatchlistMembershipProvider(widget.symbol));
    final stock = stockDefinition(widget.symbol);
    _handleUpdate(quote);

    final color = quote.isUp ? AppColors.up : AppColors.down;
    final flashColor = _flash == null
        ? Colors.transparent
        : (_flash == FlashDirection.up
            ? AppColors.flashUpBg
            : AppColors.flashDownBg);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: flashColor == Colors.transparent ? Colors.white : flashColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: isStarred ? 'Remove from watchlist' : 'Add to watchlist',
                  onPressed: _toggleStar,
                  icon: Icon(
                    isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: isStarred ? const Color(0xFFF2A900) : AppColors.muted,
                    size: 23,
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.symbol.substring(0, widget.symbol.length >= 2 ? 2 : widget.symbol.length),
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.symbol,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stock.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      quote.ltpPaise.toRupeeString(),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          quote.isUp
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          color: color,
                          size: 17,
                        ),
                        Text(
                          '${quote.changePercentValue.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
