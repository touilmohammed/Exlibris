import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  // 1. Déclarer le contrôleur explicitement
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // Évite les scans multiples
  );

  @override
  void dispose() {
    // 2. LIBÉRER la caméra impérativement ici
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le code-barres')),
      body: MobileScanner(
        controller: controller, // 3. Lier le contrôleur
        onDetect: (capture) async {
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final code = barcodes.first.rawValue;
          if (code != null) {
            // 4. ARRÊTER la caméra avant de quitter la page
            await controller.stop();

            if (!mounted) return;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
