import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayWrapper extends StatefulWidget {
  const SystemTrayWrapper({required this.child, super.key});

  final Widget child;

  @override
  State<SystemTrayWrapper> createState() => _SystemTrayWrapperState();
}

class _SystemTrayWrapperState extends State<SystemTrayWrapper>
    with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initSystemTray();
  }

  Future<void> _initSystemTray() async {
    await trayManager.setIcon('assets/flutter.jpg');
    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: 'Show',
      ),
      MenuItem(
        key: 'exit_app',
        label: 'Exit',
      ),
    ];
    await trayManager.setContextMenu(Menu(items: items));
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Container(),
        );
      },
    );
  }

  @override
  void onTrayIconMouseDown() {
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
  }

  void _exitApp() {
    trayManager.destroy();
    windowManager.destroy();
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        GestureDetector(
          onTap: _minimizeToTray,
          child: Container(
            color: Colors.black,
            height: 40,
            child: const Center(
              child: Text(
                'Minimize to tray',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        )
      ],
    );
  }
}
