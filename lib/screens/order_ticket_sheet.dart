import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/order.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import 'theme.dart';

Future<void> showOrderTicketSheet(
  BuildContext context, {
  required String symbol,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => OrderTicketSheet(symbol: symbol),
  );
}

class OrderTicketSheet extends ConsumerStatefulWidget {
  const OrderTicketSheet({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<OrderTicketSheet> createState() => _OrderTicketSheetState();
}

class _OrderTicketSheetState extends ConsumerState<OrderTicketSheet> {
  OrderSide _side = OrderSide.buy;
  final _qtyController = TextEditingController();
  String? _error;
  bool _submitting = false;
  TradeOrder? _confirmedOrder;

  int get _quantity => int.tryParse(_qtyController.text.trim()) ?? 0;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit(int ltpPaise) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final rawQty = _qtyController.text.trim();
    if (rawQty.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(rawQty) ||
        int.parse(rawQty) <= 0) {
      setState(() {
        _error = 'Enter a whole number of shares greater than zero.';
        _submitting = false;
      });
      return;
    }

    try {
      final order = await ref.read(tradeExecutorProvider).submit(
            symbol: widget.symbol,
            side: _side,
            quantity: _quantity,
            currentLtpPaise: ltpPaise,
          );
      if (!mounted) return;
      setState(() => _confirmedOrder = order);
    } on OrderRejected catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmedOrder != null) {
      return _ConfirmationView(order: _confirmedOrder!);
    }

    final quote = ref.watch(stockQuoteProvider(widget.symbol));
    final balance = ref.watch(walletBalanceProvider);
    final holdings = ref.watch(holdingsProvider);
    final held = holdings
        .where((h) => h.symbol == widget.symbol)
        .fold<int>(0, (sum, h) => sum + h.quantity);
    final orderValuePaise = _quantity * quote.ltpPaise;
    final stock = stockDefinition(widget.symbol);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEAF2FC),
                child: Text(
                  widget.symbol.substring(0, widget.symbol.length >= 2 ? 2 : widget.symbol.length),
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.symbol,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      stock.name,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quote.ltpPaise.toRupeeString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${quote.changePaise.toSignedRupeeString()} (${quote.changePercentValue.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: quote.isUp ? AppColors.up : AppColors.down,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SideButton(
                    label: 'BUY',
                    selected: _side == OrderSide.buy,
                    color: AppColors.up,
                    onTap: () => setState(() => _side = OrderSide.buy),
                  ),
                ),
                Expanded(
                  child: _SideButton(
                    label: 'SELL',
                    selected: _side == OrderSide.sell,
                    color: AppColors.down,
                    onTap: () => setState(() => _side = OrderSide.sell),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Quantity',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              suffixText: 'shares',
              suffixStyle: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(Icons.grid_3x3_rounded, size: 19),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Execution',
                  value: 'Market order',
                ),
                const SizedBox(height: 9),
                _InfoRow(
                  label: _side == OrderSide.buy ? 'Available funds' : 'Shares held',
                  value: _side == OrderSide.buy
                      ? balance.toRupeeString()
                      : '$held shares',
                ),
                const SizedBox(height: 9),
                _InfoRow(
                  label: 'Estimated value',
                  value: orderValuePaise.toRupeeString(),
                  bold: true,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.down,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _side == OrderSide.buy ? AppColors.up : AppColors.down,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting ? null : () => _submit(quote.ltpPaise),
              child: Text(
                _submitting
                    ? 'Placing order...'
                    : '${_side == OrderSide.buy ? 'Buy' : 'Sell'} ${widget.symbol}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Center(
            child: Text(
              'Simulated execution • price locked at submission',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.muted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.order});

  final TradeOrder order;

  @override
  Widget build(BuildContext context) {
    final isBuy = order.side == OrderSide.buy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (isBuy ? AppColors.up : AppColors.down).withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: isBuy ? AppColors.up : AppColors.down,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isBuy ? 'Buy order placed' : 'Sell order placed',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.quantity} ${order.symbol} @ ${order.priceAtExecutionPaise.toRupeeString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _InfoRow(
              label: 'Order value',
              value: order.valuePaise.toRupeeString(),
              bold: true,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
