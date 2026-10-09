import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/watchlist.dart';
import '../services/storage_service.dart';

const String _kWatchlistsKey = 'watchlists_v1';
const String kQuickWatchlistName = 'My Watchlist';

class WatchlistsNotifier extends StateNotifier<List<Watchlist>> {
  WatchlistsNotifier(this._storage) : super([]) {
    _load();
  }

  final StorageService _storage;
  final _uuid = const Uuid();

  Future<void> _load() async {
    state = _storage.readJson<List<Watchlist>>(_kWatchlistsKey, (decoded) {
          return (decoded as List)
              .map((e) => Watchlist.fromJson(e as Map<String, dynamic>))
              .toList();
        }) ??
        [];
  }

  Future<void> _persist() =>
      _storage.writeJson(_kWatchlistsKey, state.map((w) => w.toJson()).toList());

  Future<void> createWatchlist(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    final watchlist = Watchlist(
      id: _uuid.v4(),
      name: cleaned,
      symbols: const [],
      createdAt: DateTime.now(),
    );
    state = [...state, watchlist];
    await _persist();
  }

  Future<void> renameWatchlist(String id, String newName) async {
    final cleaned = newName.trim();
    if (cleaned.isEmpty) return;
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(name: cleaned) else w,
    ];
    await _persist();
  }

  Future<void> deleteWatchlist(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _persist();
  }

  Future<void> addStock(String watchlistId, String symbol) async {
    state = [
      for (final w in state)
        if (w.id == watchlistId && !w.symbols.contains(symbol))
          w.copyWith(symbols: [...w.symbols, symbol])
        else
          w,
    ];
    await _persist();
  }

  Future<void> removeStock(String watchlistId, String symbol) async {
    state = [
      for (final w in state)
        if (w.id == watchlistId)
          w.copyWith(symbols: w.symbols.where((s) => s != symbol).toList())
        else
          w,
    ];
    await _persist();
  }

  Future<void> reorderStock(String watchlistId, int oldIndex, int newIndex) async {
    state = [
      for (final w in state)
        if (w.id == watchlistId)
          w.copyWith(symbols: _moved(w.symbols, oldIndex, newIndex))
        else
          w,
    ];
    await _persist();
  }

  /// Quick-star behavior used by the Market screen.
  /// It creates "My Watchlist" automatically the first time the user stars
  /// a stock, then toggles that symbol in the same list.
  Future<bool> toggleQuickWatchlist(String symbol) async {
    var lists = [...state];

    if (lists.isEmpty) {
      final watchlist = Watchlist(
        id: _uuid.v4(),
        name: kQuickWatchlistName,
        symbols: [symbol],
        createdAt: DateTime.now(),
      );
      state = [watchlist];
      await _persist();
      return true;
    }

    var targetIndex = lists.indexWhere((w) => w.name == kQuickWatchlistName);
    if (targetIndex == -1) targetIndex = 0;

    final target = lists[targetIndex];
    final isAdded = target.symbols.contains(symbol);
    final updatedSymbols = isAdded
        ? target.symbols.where((s) => s != symbol).toList()
        : [...target.symbols, symbol];

    lists[targetIndex] = target.copyWith(symbols: updatedSymbols);
    state = lists;
    await _persist();
    return !isAdded;
  }

  bool isInQuickWatchlist(String symbol) {
    if (state.isEmpty) return false;
    final index = state.indexWhere((w) => w.name == kQuickWatchlistName);
    final target = state[index == -1 ? 0 : index];
    return target.symbols.contains(symbol);
  }

  String quickWatchlistName() {
    if (state.isEmpty) return kQuickWatchlistName;
    final index = state.indexWhere((w) => w.name == kQuickWatchlistName);
    return state[index == -1 ? 0 : index].name;
  }

  List<String> _moved(List<String> symbols, int oldIndex, int newIndex) {
    final updated = [...symbols];
    var target = newIndex;
    if (oldIndex < newIndex) target -= 1;
    final symbol = updated.removeAt(oldIndex);
    updated.insert(target, symbol);
    return updated;
  }
}

final watchlistsProvider =
    StateNotifierProvider<WatchlistsNotifier, List<Watchlist>>((ref) {
  return WatchlistsNotifier(ref.watch(storageServiceProvider));
});

final watchlistByIdProvider = Provider.family<Watchlist?, String>((ref, id) {
  final all = ref.watch(watchlistsProvider);
  for (final w in all) {
    if (w.id == id) return w;
  }
  return null;
});

final quickWatchlistMembershipProvider =
    Provider.family<bool, String>((ref, symbol) {
  final lists = ref.watch(watchlistsProvider);
  if (lists.isEmpty) return false;
  final index = lists.indexWhere((w) => w.name == kQuickWatchlistName);
  final target = lists[index == -1 ? 0 : index];
  return target.symbols.contains(symbol);
});
