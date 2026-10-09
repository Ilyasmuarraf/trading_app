/// A named, ordered collection of stock symbols. Order matters since
/// stocks can be drag-reordered within a watchlist.
class Watchlist {
  final String id;
  final String name;
  final List<String> symbols;
  final DateTime createdAt;

  const Watchlist({
    required this.id,
    required this.name,
    required this.symbols,
    required this.createdAt,
  });

  Watchlist copyWith({String? name, List<String>? symbols}) => Watchlist(
        id: id,
        name: name ?? this.name,
        symbols: symbols ?? this.symbols,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'symbols': symbols,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Watchlist.fromJson(Map<String, dynamic> json) => Watchlist(
        id: json['id'] as String,
        name: json['name'] as String,
        symbols: List<String>.from(json['symbols'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
