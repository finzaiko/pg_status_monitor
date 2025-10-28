import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'constants.dart';
import 'package:window_manager/window_manager.dart';
import 'settings_page.dart';
import 'tray_service.dart';
import 'db_service.dart';
import 'config_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window_manager and SharedPreferences
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Configure launch at startup
  LaunchAtStartup.instance.setup(
    appName: appName,
    appPath: Platform.resolvedExecutable,
  );

  // Update launch at startup setting
  final shouldLaunchAtStartup =
      prefs.getBool('isLaunchOnStartup') ?? isLaunchOnStartup;
  await LaunchAtStartup.instance.enable();
  if (shouldLaunchAtStartup) {
    await LaunchAtStartup.instance.enable();
  } else {
    await LaunchAtStartup.instance.disable();
  }

  // Check maximize setting
  final shouldMaximize =
      prefs.getBool('isMaximizeOnStartup') ?? isMaximizeOnStartup;

  // Configure window options
  const windowOptions = WindowOptions(
    title: appName,
    minimumSize: Size(800, 600),
    size: Size(1200, 800),
  );
  await windowManager.waitUntilReadyToShow(windowOptions);

  if (shouldMaximize) {
    await windowManager.setFullScreen(true);
  }

  // Initialize system tray
  await TrayService.initSystemTray();
  TrayService.handleTrayClick();

  runApp(MyApp(navigatorKey: navigatorKey));
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Image Viewer',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ImageViewerScreen(),
    );
  }
}

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  String? _imageUrl;
  Timer? _autoRefreshTimer;
  Timer? _serverCheckTimer;
  bool _isLoading = true;
  bool _isFullScreen = false;
  bool _isRandomImage = true;
  String? _staticImageUrl;
  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _serverStatuses = [];

  Future<void> _checkFullScreenState() async {
    _isFullScreen = await windowManager.isFullScreen();
    setState(() {});
  }

  Future<void> _toggleFullScreen() async {
    await windowManager.setFullScreen(!_isFullScreen);
    await _checkFullScreenState();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _isRandomImage = _prefs.getBool('isImageRandom') ?? isImageRandom;
    _staticImageUrl = _prefs.getString('imageStaticUrl');

    if (_isRandomImage) {
      _fetchRandomImage();
      // Start the auto-refresh timer only for random images
      final intervalMinutes =
          _prefs.getInt('randomInterval') ??
          5; // Default to 5 minutes if not set
      _autoRefreshTimer = Timer.periodic(
        Duration(minutes: intervalMinutes),
        (_) => _fetchRandomImage(),
      );
    } else if (_staticImageUrl != null && _staticImageUrl!.isNotEmpty) {
      setState(() {
        _imageUrl = _staticImageUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkServerStatuses() async {
    final statuses = await DbService().getServerStatuses();
    setState(() {
      _serverStatuses = statuses;
      // Debug print server statuses as JSON
      debugPrint('Server Statuses: ${jsonEncode(_serverStatuses)}');
    });
  }

  @override
  void initState() {
    super.initState();
    _checkFullScreenState();
    _loadSettings();
    _checkServerStatuses(); // Initial check
    _serverCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkServerStatuses(),
    );
  }

  @override
  void dispose() {
    // Cancel the timers if they exist
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;
    }
    if (_serverCheckTimer != null) {
      _serverCheckTimer!.cancel();
      _serverCheckTimer = null;
    }
    super.dispose();
  }

  Future<void> _fetchRandomImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.pexels.com/v1/search?query=$imageCategories&per_page=1&page=${1 + Random().nextInt(100)}',
        ),
        headers: {'Authorization': apiKey},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['photos'] != null && data['photos'].isNotEmpty) {
          final photo = data['photos'][0];
          final photoId = photo['id'].toString();
          final originalUrl = photo['src']['original'];
          final displayUrl = photo['src']['large2x']; // 2880x1920 size

          debugPrint('Photo ID: $photoId'); // Debug print
          debugPrint('Display URL: $displayUrl'); // Debug print
          debugPrint('Original URL: $originalUrl'); // Debug print

          setState(() {
            _imageUrl = displayUrl;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching image details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_imageUrl != null)
            Stack(
              children: [
                Image.network(
                  _imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Stack(
                      children: [
                        if (_imageUrl != null) child,
                        Container(
                          color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Text(
                          'Error loading image\nTap to try again',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onTap: _isRandomImage ? _fetchRandomImage : null,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 300,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Text(
                  'DB Server Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          if (_serverStatuses.isNotEmpty)
            Positioned(
              top: 120,
              right: 20,
              child: Container(
                width: 300,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 200,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(179), // 0.7 * 255 ≈ 179
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _serverStatuses.length,
                    itemBuilder: (context, index) {
                      final status = _serverStatuses[index];
                      final isOk = status['status'] == 'OK';
                      return ListTile(
                        leading: Icon(
                          isOk ? Icons.check_circle : Icons.error,
                          color: isOk ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          status['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${status['status']}',
                              style: TextStyle(
                                color: isOk ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isOk && status['error'].isNotEmpty)
                              Text(
                                status['error'],
                                style: const TextStyle(color: Colors.red),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                Row(
                  children: [
                    if (isSettingConfigOnScreen) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(179), // 0.7 * 255 ≈ 179
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const SettingsPage(),
                            );
                            if (result == true) {
                              // Settings were saved, reload the settings and image
                              await _loadSettings();
                            }
                          },
                          tooltip: 'Settings',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(179), // 0.7 * 255 ≈ 179
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.storage, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ConfigPage(),
                              ),
                            );
                          },
                          tooltip: 'Config Server',
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(179), // 0.7 * 255 ≈ 179
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullScreen,
                        tooltip: _isFullScreen
                            ? 'Exit Fullscreen'
                            : 'Enter Fullscreen',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(179), // 0.7 * 255 ≈ 179
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        onTap: _imageUrl != null
                            ? () {
                                launchUrl(Uri.parse(_imageUrl!));
                              }
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoading
                                  ? 'Loading image...'
                                  : 'View Original Image',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: !_isLoading
                                    ? TextDecoration.none
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isRandomImage
          ? FloatingActionButton(
              onPressed: _fetchRandomImage,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }
}
