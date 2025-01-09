import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thermal_printer/thermal_printer.dart';

class PrinterListener extends StatefulWidget {
  const PrinterListener({required this.child, super.key});

  final Widget child;

  @override
  State<PrinterListener> createState() => _PrinterListenerState();
}

class _PrinterListenerState extends State<PrinterListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      startScan();
    });
  }

  void _printDocs({String? content}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    // bytes += generator.text('Bold text', styles: const PosStyles(bold: true));
    // bytes += generator.text('Normal text');

    String qrData = content ?? "google com";
    const double qrSize = 200;
    try {
      final uiImg = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
      ).toImageData(qrSize);
      if (uiImg == null) return;
      final dir = await getTemporaryDirectory();
      final pathName = '${dir.path}/qr_tmp.png';
      final qrFile = File(pathName);
      final imgFile = await qrFile.writeAsBytes(uiImg.buffer.asUint8List());
      final img = image.decodeImage(imgFile.readAsBytesSync());

      bytes += generator.image(img!);
      bytes += generator.text('Content: $qrData');
    } catch (e) {
      debugPrint(e.toString());
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    _connectDevice(devices.first, PrinterType.usb);
    final result =
        await PrinterManager.instance.send(bytes: bytes, type: PrinterType.usb);
    debugPrint(result.toString());
  }

  String _barcodeBuffer = '';
  Timer? _timer;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  List<PrinterDevice> devices = [];
  void startScan() async {
    PrinterManager.instance
        .discovery(
      type: PrinterType.usb,
    )
        .listen((device) {
      if (device.name == "Docket") {
        devices.add(device);
      }
    });
  }

  _connectDevice(PrinterDevice selectedPrinter, PrinterType type,
      {bool reconnect = false, bool isBle = false, String? ipAddress}) async {
    switch (type) {
      // only windows and android
      case PrinterType.usb:
        await PrinterManager.instance.connect(
            type: type,
            model: UsbPrinterInput(
                name: selectedPrinter.name,
                productId: selectedPrinter.productId,
                vendorId: selectedPrinter.vendorId));
        break;
      // only iOS and android
      case PrinterType.bluetooth:
        await PrinterManager.instance.connect(
            type: type,
            model: BluetoothPrinterInput(
                name: selectedPrinter.name,
                address: selectedPrinter.address!,
                isBle: isBle,
                autoConnect: reconnect));
        break;
      case PrinterType.network:
        await PrinterManager.instance.connect(
            type: type,
            model: TcpPrinterInput(
                ipAddress: ipAddress ?? selectedPrinter.address!));
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              decoration: const InputDecoration.collapsed(hintText: ""),
              onChanged: (value) {
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 300), () {
                  if (value.isNotEmpty) {
                    _barcodeBuffer = value;
                    _controller.clear();
                    debugPrint("Scanned Barcode: $_barcodeBuffer");
                    _printDocs(content: _barcodeBuffer);
                  }
                });
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
