import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaymentQrScanScreen extends StatefulWidget {
  const PaymentQrScanScreen({super.key});

  @override
  State<PaymentQrScanScreen> createState() => _PaymentQrScanScreenState();
}

class _PaymentQrScanScreenState extends State<PaymentQrScanScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan UPI QR'),
      ),
      body: MobileScanner(
        onDetect: (barcodeCapture) {
          if (_isScanned) return;

          final barcode = barcodeCapture.barcodes.first;
          final rawValue = barcode.rawValue;

          if (rawValue != null && rawValue.isNotEmpty) {
            _isScanned = true;

            Navigator.pop(context, rawValue);
          }
        },
      ),
    );
  }
}
