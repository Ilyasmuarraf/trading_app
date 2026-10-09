/// A single price update emitted by the mock market data feed.
/// This is the atomic unit the whole app's live pricing is built on.
class StockTick {
  final String symbol;
  final int pricePaise;
  final DateTime timestamp;

  const StockTick({
    required this.symbol,
    required this.pricePaise,
    required this.timestamp,
  });
}
