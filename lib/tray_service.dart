import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'settings_page.dart';
import 'config_page.dart';

class TrayService {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  static Future<void> initSystemTray() async {
    try {
      String iconPath = 'assets/images/app_icon.png';
      if (Platform.isLinux) {
        // On Linux, first try to use our custom icon
        try {
          await TrayManager.instance.setIcon(iconPath);
        } catch (e) {
          // If custom icon fails, fall back to system icon
          iconPath = 'image-x-generic';
          await TrayManager.instance.setIcon(iconPath);
        }
      } else {
        await TrayManager.instance.setIcon(iconPath);
      }

      // Create menu items
      final List<MenuItem> items = [
        MenuItem(key: 'config_server', label: 'Config Server'),
        MenuItem(key: 'settings', label: 'Settings'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ];

      await TrayManager.instance.setContextMenu(Menu(items: items));
    } catch (e) {
      debugPrint('Error initializing system tray: $e');
    }
  }

  static void handleTrayClick() {
    TrayManager.instance.addListener(_TrayListener());
  }
}

class _TrayListener with TrayListener {
  @override
  void onTrayIconRightMouseDown() async {
    await TrayManager.instance.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'config_server':
        await windowManager.show();
        await windowManager.focus();
        if (navigatorKey.currentContext != null) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(builder: (context) => const ConfigPage()),
          );
        }
        break;
      case 'settings':
        await windowManager.show();
        await windowManager.focus();
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => const SettingsPage(),
          );
        }
        break;
      case 'exit':
        await windowManager.close();
        break;
    }
  }
}

// Global navigator key for accessing context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
