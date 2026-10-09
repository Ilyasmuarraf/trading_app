import 'package:intl/intl.dart';

// ─── Stock universe ──────────────────────────────────────────────

class StockDef {
  final String symbol;
  final String name;
  final int startPricePaise;

  const StockDef({
    required this.symbol,
    required this.name,
    required this.startPricePaise,
  });
}

const List<StockDef> kStockUniverse = [
  StockDef(symbol: 'RELIANCE', name: 'Reliance Industries', startPricePaise: 284500),
  StockDef(symbol: 'TCS', name: 'Tata Consultancy Services', startPricePaise: 384200),
  StockDef(symbol: 'INFY', name: 'Infosys', startPricePaise: 154300),
  StockDef(symbol: 'HDFCBANK', name: 'HDFC Bank', startPricePaise: 162800),
  StockDef(symbol: 'ICICIBANK', name: 'ICICI Bank', startPricePaise: 118900),
  StockDef(symbol: 'SBIN', name: 'State Bank of India', startPricePaise: 81200),
  StockDef(symbol: 'ITC', name: 'ITC Limited', startPricePaise: 43500),
  StockDef(symbol: 'LT', name: 'Larsen & Toubro', startPricePaise: 356700),
  StockDef(symbol: 'BHARTIARTL', name: 'Bharti Airtel', startPricePaise: 159400),
  StockDef(symbol: 'AXISBANK', name: 'Axis Bank', startPricePaise: 108600),
];

const List<String> kStockSymbols = [
  'RELIANCE',
  'TCS',
  'INFY',
  'HDFCBANK',
  'ICICIBANK',
  'SBIN',
  'ITC',
  'LT',
  'BHARTIARTL',
  'AXISBANK',
];

StockDef stockDefinition(String symbol) =>
    kStockUniverse.firstWhere((stock) => stock.symbol == symbol);

extension PaiseFormatting on int {
  String toRupeeString({bool withSymbol = true}) {
    final rupees = this / 100.0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: withSymbol ? '₹' : '',
      decimalDigits: 2,
    );
    return formatter.format(rupees).trim();
  }

  String toSignedRupeeString() {
    final sign = this >= 0 ? '+' : '-';
    return '$sign${abs().toRupeeString()}';
  }

  String toCompactRupeeString() {
    final value = this.abs() / 100;
    final prefix = this < 0 ? '-' : '';
    if (value >= 10000000) {
      return '$prefix₹${(value / 10000000).toStringAsFixed(2)}Cr';
    }
    if (value >= 100000) {
      return '$prefix₹${(value / 100000).toStringAsFixed(2)}L';
    }
    if (value >= 1000) {
      return '$prefix₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '${this < 0 ? '-' : ''}₹${value.toStringAsFixed(2)}';
  }
}

int? parseRupeeStringToPaise(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmed)) return null;

  final parts = trimmed.split('.');
  final rupeesPart = int.parse(parts[0]);
  int paisePart = 0;
  if (parts.length == 2) {
    final fraction = parts[1].padRight(2, '0');
    paisePart = int.parse(fraction);
  }
  return rupeesPart * 100 + paisePart;
}

double changePercent(int currentPaise, int basePaise) {
  if (basePaise == 0) return 0;
  return ((currentPaise - basePaise) / basePaise) * 100;
}
