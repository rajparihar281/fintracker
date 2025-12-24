import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UpiQrCode extends StatelessWidget {
  final String upiId;
  final String payeeName;
  final double amount;
  final String transactionNote;

  const UpiQrCode({
    super.key,
    required this.upiId,
    required this.payeeName,
    required this.amount,
    required this.transactionNote,
  });

  String _generateUpiString() {
    return 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&tn=${Uri.encodeComponent(transactionNote)}&cu=INR';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan to Pay',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: _generateUpiString(),
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Amount: ₹${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'UPI ID: $upiId',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}