import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_demo/printer_listener.dart';
import 'package:flutter_pos_printer_demo/system_tray.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init window_manager
  await windowManager.ensureInitialized();

  // set window properties
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

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: PrinterListener(
        child: SystemTrayWrapper(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset('assets/flutter.jpg'),
              ElevatedButton(
                focusNode: FocusNode(skipTraversal: true),
                onPressed: () {},
                child: const Text('Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
