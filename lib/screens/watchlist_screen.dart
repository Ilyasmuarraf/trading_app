import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../providers/watchlist_provider.dart';
import 'live_market_screen.dart';
import 'order_ticket_sheet.dart';
import 'theme.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  Future<void> _createWatchlist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create watchlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Banking',
            prefixIcon: Icon(Icons.star_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty) {
      await ref.read(watchlistsProvider.notifier).createWatchlist(name);
    }
  }

  Future<void> _renameWatchlist(
    BuildContext context,
    WidgetRef ref,
    String id,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename watchlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty) {
      await ref.read(watchlistsProvider.notifier).renameWatchlist(id, name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlists = ref.watch(watchlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            tooltip: 'New watchlist',
            onPressed: () => _createWatchlist(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: watchlists.isEmpty
          ? _EmptyWatchlist(onCreate: () => _createWatchlist(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: watchlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final w = watchlists[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WatchlistDetailScreen(watchlistId: w.id),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6E5),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF2A900),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${w.symbols.length} stocks',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'rename') {
                                _renameWatchlist(context, ref, w.id, w.name);
                              } else if (action == 'delete') {
                                ref
                                    .read(watchlistsProvider.notifier)
                                    .deleteWatchlist(w.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFF2A900),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Build your watchlist',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the star beside any stock in Market to add it instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create watchlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class WatchlistDetailScreen extends ConsumerWidget {
  const WatchlistDetailScreen({super.key, required this.watchlistId});

  final String watchlistId;

  Future<void> _addStock(
    BuildContext context,
    WidgetRef ref,
    List<String> alreadyAdded,
  ) async {
    final symbol = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StockPickerSheet(alreadyAdded: alreadyAdded),
    );
    if (symbol != null) {
      await ref.read(watchlistsProvider.notifier).addStock(watchlistId, symbol);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistByIdProvider(watchlistId));

    if (watchlist == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(watchlist.name),
        actions: [
          IconButton(
            tooltip: 'Add stock',
            onPressed: () => _addStock(context, ref, watchlist.symbols),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: watchlist.symbols.isEmpty
          ? const Center(
              child: Text(
                'No stocks yet. Tap + to add one.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: watchlist.symbols.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(watchlistsProvider.notifier)
                    .reorderStock(watchlistId, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final symbol = watchlist.symbols[index];
                return Card(
                  key: ValueKey('$watchlistId-$symbol'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: LivePriceTile(
                          symbol: symbol,
                          onTap: () => showOrderTicketSheet(
                            context,
                            symbol: symbol,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => ref
                            .read(watchlistsProvider.notifier)
                            .removeStock(watchlistId, symbol),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _StockPickerSheet extends StatelessWidget {
  const _StockPickerSheet({required this.alreadyAdded});

  final List<String> alreadyAdded;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Add a stock',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a stock for this watchlist.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          ...kStockUniverse.map((def) {
            final added = alreadyAdded.contains(def.symbol);
            return ListTile(
              enabled: !added,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF0F4FA),
                child: Text(
                  def.symbol.substring(0, def.symbol.length >= 2 ? 2 : def.symbol.length),
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                def.symbol,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(def.name),
              trailing: added
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.up)
                  : const Icon(Icons.add_circle_outline_rounded),
              onTap: added
                  ? null
                  : () => Navigator.of(context).pop(def.symbol),
            );
          }),
        ],
      ),
    );
  }
}
