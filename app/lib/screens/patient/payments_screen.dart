import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() => context.read<PaymentProvider>().fetchMine();

  Color _statusColor(String status) {
    switch (status) {
      case 'Success':
        return AppColors.success;
      case 'Failed':
      case 'Cancelled':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'Esewa':
      case 'Khalti':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loading
            ? const LoadingView()
            : provider.error != null
                ? ErrorView(message: provider.error!, onRetry: _refresh)
                : provider.payments.isEmpty
                    ? const EmptyView(
                        message: 'No payments yet.\nPay for a consultation from its appointment.',
                        icon: Icons.receipt_long_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final p = provider.payments[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(p.status).withValues(alpha: 0.12),
                                child: Icon(_methodIcon(p.method), color: _statusColor(p.status)),
                              ),
                              title: Text('Rs. ${p.amount.toStringAsFixed(2)} · ${p.method}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${p.doctorName != null ? 'Dr. ${p.doctorName} · ' : ''}'
                                '${DateFormat.yMMMd().add_jm().format(p.paidAt ?? p.createdAt)}',
                              ),
                              trailing: StatusChip(status: p.status),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
