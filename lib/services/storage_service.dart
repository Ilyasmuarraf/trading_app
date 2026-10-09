import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence layer over SharedPreferences. Everything is
/// stored as JSON strings so the providers that use it stay
/// storage-agnostic and this is the only class in the app that knows
/// about SharedPreferences directly.
class StorageService {
  StorageService._(this._prefs);
  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  T? readJson<T>(String key, T Function(dynamic decoded) decode) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return decode(jsonDecode(raw));
  }

  Future<void> writeInt(String key, int value) => _prefs.setInt(key, value);
  int? readInt(String key) => _prefs.getInt(key);

  Future<void> remove(String key) => _prefs.remove(key);
}

/// Overridden in main() once the async StorageService is ready, so
/// watchlist_provider.dart / portfolio_provider.dart can depend on it
/// synchronously. Lives here (next to the class it provides) since
/// this app has no separate top-level "app providers" file.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be overridden in main() with a real StorageService instance.',
  );
});
