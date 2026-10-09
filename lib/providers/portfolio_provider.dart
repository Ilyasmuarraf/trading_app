import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/holding.dart';
import '../models/order.dart';
import '../services/storage_service.dart';

// This file groups wallet balance, holdings, and order history behind
// one "portfolio" umbrella, because those three always move together
// (see TradeExecutor at the bottom) - splitting them into three files
// would just scatter one atomic operation across the codebase.

const String _kWalletKey = 'wallet_balance_paise_v1';
const String _kHoldingsKey = 'holdings_v1';
const String _kOrdersKey = 'orders_v1';

/// Starting margin: ₹10,00,000.
const int kStartingBalancePaise = 1000000 * 100;

// ─── Wallet ──────────────────────────────────────────────────────

class WalletNotifier extends StateNotifier<int> {
  WalletNotifier(this._storage) : super(_storage.readInt(_kWalletKey) ?? kStartingBalancePaise);
  final StorageService _storage;

  Future<void> debit(int amountPaise) async {
    state -= amountPaise;
    await _storage.writeInt(_kWalletKey, state);
  }

  Future<void> credit(int amountPaise) async {
    state += amountPaise;
    await _storage.writeInt(_kWalletKey, state);
  }
}

/// Wallet balance in paise.
final walletBalanceProvider = StateNotifierProvider<WalletNotifier, int>((ref) {
  return WalletNotifier(ref.watch(storageServiceProvider));
});

// ─── Holdings ────────────────────────────────────────────────────

class HoldingsNotifier extends StateNotifier<List<Holding>> {
  HoldingsNotifier(this._storage) : super([]) {
    _load();
  }
  final StorageService _storage;

  Future<void> _load() async {
    state = _storage.readJson<List<Holding>>(_kHoldingsKey, (decoded) {
          return (decoded as List)
              .map((e) => Holding.fromJson(e as Map<String, dynamic>))
              .toList();
        }) ??
        [];
  }

  Future<void> _persist() =>
      _storage.writeJson(_kHoldingsKey, state.map((h) => h.toJson()).toList());

  /// Applies a filled buy: creates the holding, or extends it and
  /// recomputes a weighted-average cost. All math is done in integer
  /// paise, with a single rounding step at the very end, so repeated
  /// buys never accumulate floating-point drift.
  Future<void> applyBuy(String symbol, int quantity, int pricePaise) async {
    final index = state.indexWhere((h) => h.symbol == symbol);
    if (index == -1) {
      state = [...state, Holding(symbol: symbol, quantity: quantity, avgCostPaise: pricePaise)];
    } else {
      final existing = state[index];
      final totalCostPaise =
          existing.avgCostPaise * existing.quantity + pricePaise * quantity;
      final totalQuantity = existing.quantity + quantity;
      final newAvgCostPaise = (totalCostPaise / totalQuantity).round();
      state = [
        for (final h in state)
          if (h.symbol == symbol)
            h.copyWith(quantity: totalQuantity, avgCostPaise: newAvgCostPaise)
          else
            h,
      ];
    }
    await _persist();
  }

  /// Applies a filled sell: reduces quantity, removing the holding
  /// entirely once it reaches zero. Avg cost is unchanged by sells.
  Future<void> applySell(String symbol, int quantity) async {
    final existing = state.firstWhere((h) => h.symbol == symbol);
    final remaining = existing.quantity - quantity;
    if (remaining <= 0) {
      state = state.where((h) => h.symbol != symbol).toList();
    } else {
      state = [
        for (final h in state)
          if (h.symbol == symbol) h.copyWith(quantity: remaining) else h,
      ];
    }
    await _persist();
  }

  int quantityHeld(String symbol) {
    final match = state.where((h) => h.symbol == symbol);
    return match.isEmpty ? 0 : match.first.quantity;
  }
}

final holdingsProvider = StateNotifierProvider<HoldingsNotifier, List<Holding>>((ref) {
  return HoldingsNotifier(ref.watch(storageServiceProvider));
});

// ─── Orders ──────────────────────────────────────────────────────

class OrdersNotifier extends StateNotifier<List<TradeOrder>> {
  OrdersNotifier(this._storage) : super([]) {
    _load();
  }
  final StorageService _storage;
  final _uuid = const Uuid();

  Future<void> _load() async {
    state = _storage.readJson<List<TradeOrder>>(_kOrdersKey, (decoded) {
          return (decoded as List)
              .map((e) => TradeOrder.fromJson(e as Map<String, dynamic>))
              .toList();
        }) ??
        [];
  }

  Future<TradeOrder> record({
    required String symbol,
    required OrderSide side,
    required int quantity,
    required int priceAtExecutionPaise,
  }) async {
    final order = TradeOrder(
      id: _uuid.v4(),
      symbol: symbol,
      side: side,
      quantity: quantity,
      priceAtExecutionPaise: priceAtExecutionPaise,
      timestamp: DateTime.now(),
    );
    state = [order, ...state];
    await _storage.writeJson(_kOrdersKey, state.map((o) => o.toJson()).toList());
    return order;
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, List<TradeOrder>>((ref) {
  return OrdersNotifier(ref.watch(storageServiceProvider));
});

// ─── Trade execution ─────────────────────────────────────────────

/// Thrown when a submitted order fails validation, carrying a message
/// suitable for direct inline display on the order ticket sheet.
class OrderRejected implements Exception {
  OrderRejected(this.message);
  final String message;
}

/// Orchestrates a full buy/sell submission: validates against wallet
/// or holdings, then atomically updates wallet, holdings, and order
/// history together. This is the ONLY place that should mutate those
/// three, so they can never drift out of sync with each other.
class TradeExecutor {
  TradeExecutor(this.ref);
  final Ref ref;

  Future<TradeOrder> submit({
    required String symbol,
    required OrderSide side,
    required int quantity,
    required int currentLtpPaise,
  }) async {
    if (quantity <= 0) {
      throw OrderRejected('Quantity must be a positive whole number.');
    }

    final orderValuePaise = quantity * currentLtpPaise;

    if (side == OrderSide.buy) {
      final balance = ref.read(walletBalanceProvider);
      if (orderValuePaise > balance) {
        throw OrderRejected('Order value exceeds available balance.');
      }
      await ref.read(walletBalanceProvider.notifier).debit(orderValuePaise);
      await ref.read(holdingsProvider.notifier).applyBuy(symbol, quantity, currentLtpPaise);
    } else {
      final held = ref.read(holdingsProvider.notifier).quantityHeld(symbol);
      if (quantity > held) {
        throw OrderRejected('You only hold $held shares of $symbol.');
      }
      await ref.read(holdingsProvider.notifier).applySell(symbol, quantity);
      await ref.read(walletBalanceProvider.notifier).credit(orderValuePaise);
    }

    return ref.read(ordersProvider.notifier).record(
          symbol: symbol,
          side: side,
          quantity: quantity,
          priceAtExecutionPaise: currentLtpPaise,
        );
  }
}

final tradeExecutorProvider = Provider<TradeExecutor>((ref) => TradeExecutor(ref));
