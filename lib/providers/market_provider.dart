import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/stock_tick.dart';
import '../services/market_feed_service.dart';

/// Debug setting: how many ticks per second, per stock, the mock feed
/// emits. Bump this to the stress-test level (5+) to verify the UI
/// stays smooth, per Feature 2's requirements. Wire
/// [MarketFeedService.setTickRate] to a debug menu to change it live.
const double kDefaultTicksPerSecondPerStock = 1.0;

/// The live, derived state of a single stock. There's no separate
/// model file for this - it's created purely from ticks plus the
/// session's opening price, so it lives right next to the provider
/// that produces it.
class StockQuote {
  final String symbol;
  final int ltpPaise;
  final int openPricePaise;

  const StockQuote({
    required this.symbol,
    required this.ltpPaise,
    required this.openPricePaise,
  });

  int get changePaise => ltpPaise - openPricePaise;
  double get changePercentValue => changePercent(ltpPaise, openPricePaise);
  bool get isUp => changePaise >= 0;

  StockQuote copyWith({int? ltpPaise}) => StockQuote(
        symbol: symbol,
        ltpPaise: ltpPaise ?? this.ltpPaise,
        openPricePaise: openPricePaise,
      );
}

/// The single, app-wide instance of the mock feed - kept alive for
/// the lifetime of the app so every screen shares the exact same
/// stream and never shows two different prices for the same symbol.
final marketFeedServiceProvider = Provider<MarketFeedService>((ref) {
  final service = MarketFeedService(
    ticksPerSecondPerStock: kDefaultTicksPerSecondPerStock,
  )..start();
  ref.onDispose(service.dispose);
  return service;
});

enum FlashDirection { up, down }

/// Holds live [StockQuote] for every symbol. Only the entry that
/// actually changed is replaced on each tick. Widgets should NOT
/// watch this directly - use [stockQuoteProvider] below - so a tick
/// for RELIANCE never rebuilds a widget only showing TCS.
class StockQuotesNotifier extends StateNotifier<Map<String, StockQuote>> {
  StockQuotesNotifier(this._feed) : super(_initial(_feed)) {
    _sub = _feed.ticks.listen(_onTick);
  }

  final MarketFeedService _feed;
  late final StreamSubscription<StockTick> _sub;

  static Map<String, StockQuote> _initial(MarketFeedService feed) {
    return {
      for (final symbol in kStockSymbols)
        symbol: StockQuote(
          symbol: symbol,
          ltpPaise: feed.lastPriceOf(symbol),
          openPricePaise: feed.openPriceOf(symbol),
        ),
    };
  }

  void _onTick(StockTick tick) {
    final current = state[tick.symbol]!;
    state = {
      ...state,
      tick.symbol: current.copyWith(ltpPaise: tick.pricePaise),
    };
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final stockQuotesProvider =
    StateNotifierProvider<StockQuotesNotifier, Map<String, StockQuote>>((ref) {
  final feed = ref.watch(marketFeedServiceProvider);
  return StockQuotesNotifier(feed);
});

/// Selective subscription to a single symbol's live quote. Almost
/// every widget in the app should use THIS, not [stockQuotesProvider]
/// directly, so a tick for one symbol only rebuilds the widget(s)
/// actually watching that symbol - the key correctness/perf
/// requirement behind Feature 2.
final stockQuoteProvider = Provider.family<StockQuote, String>((ref, symbol) {
  return ref.watch(stockQuotesProvider.select((m) => m[symbol]!));
});
