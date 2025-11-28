import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le code-barres')),
      body: MobileScanner(
        // on appelle Navigator.pop dès qu'on a un code valide
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final code = barcodes.first.rawValue;
          if (code == null) return;

          // On retourne le code scanné à la page précédente
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
