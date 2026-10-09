enum OrderSide { buy, sell }

/// A single filled (simulated) market order, executed at the LTP at
/// the moment of submission.
class TradeOrder {
  final String id;
  final String symbol;
  final OrderSide side;
  final int quantity;
  final int priceAtExecutionPaise;
  final DateTime timestamp;

  const TradeOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.priceAtExecutionPaise,
    required this.timestamp,
  });

  int get valuePaise => quantity * priceAtExecutionPaise;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side.name,
        'quantity': quantity,
        'priceAtExecutionPaise': priceAtExecutionPaise,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TradeOrder.fromJson(Map<String, dynamic> json) => TradeOrder(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        side: OrderSide.values.byName(json['side'] as String),
        quantity: json['quantity'] as int,
        priceAtExecutionPaise: json['priceAtExecutionPaise'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
