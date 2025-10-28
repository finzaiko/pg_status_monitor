import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Form controllers
  final _apiKeyController = TextEditingController();
  final _imageCategoryController = TextEditingController();
  final _imageStaticUrlController = TextEditingController();
  final _randomIntervalController = TextEditingController();

  // Form values
  bool _isRandomImage = false;
  bool _launchOnStartup = false;
  bool _maximizeOnStartup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _imageCategoryController.dispose();
    _imageStaticUrlController.dispose();
    _randomIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      _apiKeyController.text = _prefs.getString('apiKey') ?? apiKey;
      _imageCategoryController.text =
          _prefs.getString('imageCategories') ?? imageCategories;
      _imageStaticUrlController.text = _prefs.getString('imageStaticUrl') ?? '';
      _isRandomImage = _prefs.getBool('isImageRandom') ?? isImageRandom;
      _randomIntervalController.text =
          (_prefs.getInt('randomInterval') ?? randomIntervalDefault).toString();
      _launchOnStartup =
          _prefs.getBool('isLaunchOnStartup') ?? isLaunchOnStartup;
      _maximizeOnStartup =
          _prefs.getBool('isMaximizeOnStartup') ?? isMaximizeOnStartup;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    await _prefs.setString('apiKey', _apiKeyController.text);
    await _prefs.setString('imageCategories', _imageCategoryController.text);
    await _prefs.setString('imageStaticUrl', _imageStaticUrlController.text);
    await _prefs.setBool('isImageRandom', _isRandomImage);
    await _prefs.setInt(
      'randomInterval',
      int.parse(_randomIntervalController.text),
    );
    await _prefs.setBool('isLaunchOnStartup', _launchOnStartup);
    // Update launch at startup setting
    if (_launchOnStartup) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
    await _prefs.setBool('isMaximizeOnStartup', _maximizeOnStartup);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(true); // Return true to indicate settings were saved
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Pexels.com API Key',
                  helperText: 'Enter your Pexels API key',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _imageCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Image Category',
                  helperText:
                      'Enter image search category (e.g., landscape, cityscape)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _imageStaticUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image Static URL',
                  helperText: 'Optional: Enter a static image URL',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Random Image'),
                subtitle: const Text('Enable random image selection'),
                value: _isRandomImage,
                onChanged: (bool value) {
                  setState(() => _isRandomImage = value);
                },
              ),
              if (_isRandomImage)
                TextFormField(
                  controller: _randomIntervalController,
                  decoration: const InputDecoration(
                    labelText: 'Random Interval (minutes)',
                    helperText: 'Time between image changes',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an interval';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 1) {
                      return 'Please enter a valid number greater than 0';
                    }
                    return null;
                  },
                ),
              SwitchListTile(
                title: const Text('Launch on Startup'),
                subtitle: const Text('Start application with system'),
                value: _launchOnStartup,
                onChanged: (bool value) {
                  setState(() => _launchOnStartup = value);
                },
              ),
              SwitchListTile(
                title: const Text('Maximize on Startup'),
                subtitle: const Text('Start in fullscreen mode'),
                value: _maximizeOnStartup,
                onChanged: (bool value) {
                  setState(() => _maximizeOnStartup = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
      ],
    );
  }
}
