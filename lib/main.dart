import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thermal_printer/thermal_printer.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 window_manager
  await windowManager.ensureInitialized();

  // 配置窗口默认属性
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle('Flutter 托盘示例');
    await windowManager.setSize(const Size(400, 600));
    await windowManager.setMinimumSize(const Size(400, 600));
    await windowManager.center();
    await windowManager.show();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TrayListener {
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
      print(e);
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    _connectDevice(devices.first, PrinterType.usb);
    final result =
        await PrinterManager.instance.send(bytes: bytes, type: PrinterType.usb);
    print(result);
  }

  String _barcodeBuffer = '';
  Timer? _timer;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      startScan();
    });

    trayManager.addListener(this);
    _initSystemTray();
  }

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

  Future<void> _initSystemTray() async {
    // 设置托盘图标
    await trayManager.setIcon('assets/flutter.jpg');

    // 创建托盘菜单项
    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: '显示窗口',
      ),
      MenuItem(
        key: 'exit_app',
        label: '退出',
      ),
    ];
    await trayManager.setContextMenu(Menu(items: items));
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
    // 显示遮罩层
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // 透明遮罩
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            Navigator.of(context).pop(); // 关闭遮罩
          },
          child: Container(),
        );
      },
    );
  }

  @override
  void onTrayIconMouseDown() {
    // 点击托盘图标显示窗口
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      _showWindow();
    } else if (menuItem.key == 'exit_app') {
      _exitApp();
    }
  }

  void _showWindow() {
    windowManager.show();
    // windowManager.setFocus();
  }

  void _minimizeToTray() {
    windowManager.hide();
    // Future.delayed(const Duration(seconds: 5), () {
    //   _printDocs();
    // });
  }

  void _exitApp() {
    trayManager.destroy();
    windowManager.destroy();
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset('assets/flutter.jpg'),
              // 隐藏的 TextField，仅用于监听条码输入
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
                        print("Scanned Barcode: $_barcodeBuffer");
                        _printDocs(content: _barcodeBuffer);
                      }
                    });
                  },
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  _minimizeToTray();
                },
                child: const Text('最小化到托盘'),
              ),
              ElevatedButton(
                focusNode: FocusNode(skipTraversal: true),
                onPressed: () {},
                child: const Text('Test'),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _printDocs,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
