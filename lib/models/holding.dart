/// A held position in a single stock. Live value/P&L are deliberately
/// NOT stored here - they're derived at read time from this plus the
/// current LTP from the price feed, so they can never go stale
/// relative to ticks.
class Holding {
  final String symbol;
  final int quantity;
  final int avgCostPaise;

  const Holding({
    required this.symbol,
    required this.quantity,
    required this.avgCostPaise,
  });

  Holding copyWith({int? quantity, int? avgCostPaise}) => Holding(
        symbol: symbol,
        quantity: quantity ?? this.quantity,
        avgCostPaise: avgCostPaise ?? this.avgCostPaise,
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'quantity': quantity,
        'avgCostPaise': avgCostPaise,
      };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        symbol: json['symbol'] as String,
        quantity: json['quantity'] as int,
        avgCostPaise: json['avgCostPaise'] as int,
      );
}
