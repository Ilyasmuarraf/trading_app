import 'dart:async';
import 'dart:math';
import '../constants.dart';
import '../models/stock_tick.dart';

/// The single source of truth for live prices in the app.
///
/// Runs one repeating [Timer]. On every firing it randomly selects a
/// subset of stocks to move (a real feed doesn't move every symbol on
/// every tick) and emits a [StockTick] per moved symbol on a single
/// broadcast stream. Every screen listens to the SAME stream/instance
/// via market_provider.dart, so two widgets showing the same symbol
/// (e.g. it's in a watchlist AND held) are always perfectly in sync.
class MarketFeedService {
  MarketFeedService({double ticksPerSecondPerStock = 1.0})
      : _ticksPerSecondPerStock = ticksPerSecondPerStock {
    for (final def in kStockUniverse) {
      _lastPricePaise[def.symbol] = def.startPricePaise;
      _openPricePaise[def.symbol] = def.startPricePaise;
    }
  }

  final _random = Random();
  final Map<String, int> _lastPricePaise = {};
  final Map<String, int> _openPricePaise = {};
  final _controller = StreamController<StockTick>.broadcast();
  Timer? _timer;
  double _ticksPerSecondPerStock;

  bool get isRunning => _timer != null;
  Stream<StockTick> get ticks => _controller.stream;

  int openPriceOf(String symbol) => _openPricePaise[symbol]!;
  int lastPriceOf(String symbol) => _lastPricePaise[symbol]!;

  /// Starts the feed. Safe to call again (e.g. after changing the
  /// tick rate) - it restarts the timer with the new rate without
  /// resetting current prices.
  void start() {
    _timer?.cancel();
    // Fire on a short master interval; each stock independently has a
    // probability-per-firing of moving, so the *effective* per-stock
    // rate matches ticksPerSecondPerStock regardless of stock count.
    // This also staggers ticks instead of moving all 10 stocks in
    // lockstep, which spreads UI work across frames.
    const masterIntervalMs = 100; // 10 firings/sec
    final perFiringProbability =
        (_ticksPerSecondPerStock * masterIntervalMs / 1000).clamp(0.0, 1.0);
    _timer = Timer.periodic(const Duration(milliseconds: masterIntervalMs), (_) {
      final now = DateTime.now();
      for (final symbol in kStockSymbols) {
        if (_random.nextDouble() > perFiringProbability) continue;
        _moveOne(symbol, now);
      }
    });
  }

  /// Adjusts the tick rate live (debug setting) without dropping the
  /// current prices. Bump this to 5.0+ per-stock to reproduce Feature
  /// 2's stress-test scenario (50+ ticks/sec overall).
  void setTickRate(double ticksPerSecondPerStock) {
    _ticksPerSecondPerStock = ticksPerSecondPerStock;
    if (isRunning) start();
  }

  void _moveOne(String symbol, DateTime now) {
    final current = _lastPricePaise[symbol]!;
    // Random walk: +/- up to ~0.15% of current price, minimum 1 paise
    // step so even cheap stocks (e.g. ITC) still visibly move.
    final maxStepPaise = max(1, (current * 0.0015).round());
    final step = _random.nextInt(maxStepPaise * 2 + 1) - maxStepPaise;
    final next = max(1, current + step);
    _lastPricePaise[symbol] = next;
    _controller.add(StockTick(symbol: symbol, pricePaise: next, timestamp: now));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
