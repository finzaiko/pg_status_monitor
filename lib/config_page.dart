import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ConfigItem {
  final String name;
  final String username;
  final String password;
  final String host;
  final String port;
  final String database;
  late String connectionString;

  ConfigItem({
    required this.name,
    required this.username,
    required this.password,
    required this.host,
    required this.port,
    required this.database,
  }) {
    connectionString = _buildConnectionString();
  }

  String _buildConnectionString() {
    final encodedPassword = Uri.encodeComponent(password);
    return 'postgresql://$username:$encodedPassword@$host:$port/$database';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'password': password,
    'host': host,
    'port': port,
    'database': database,
    'connectionString': connectionString,
  };

  factory ConfigItem.fromJson(Map<String, dynamic> json) => ConfigItem(
    name: json['name'] as String,
    username: json['username'] as String,
    password: json['password'] as String,
    host: json['host'] as String,
    port: json['port'] as String,
    database: json['database'] as String,
  );
}

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _databaseController = TextEditingController();
  late SharedPreferences _prefs;
  List<ConfigItem> _configurations = [];
  bool _isLoading = true;
  bool _isEditing = false;
  int _editingIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigurations() async {
    _prefs = await SharedPreferences.getInstance();
    final configsJson = _prefs.getStringList('configurations') ?? [];
    setState(() {
      _configurations = configsJson
          .map((json) => ConfigItem.fromJson(jsonDecode(json)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveConfigurations() async {
    final configsJson = _configurations
        .map((config) => jsonEncode(config.toJson()))
        .toList();
    await _prefs.setStringList('configurations', configsJson);
  }

  void _addConfiguration() async {
    if (_formKey.currentState!.validate()) {
      final newConfig = ConfigItem(
        name: _nameController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        host: _hostController.text,
        port: _portController.text.isEmpty ? '5432' : _portController.text,
        database: _databaseController.text,
      );

      setState(() {
        if (_isEditing) {
          _configurations[_editingIndex] = newConfig;
          _isEditing = false;
          _editingIndex = -1;
        } else {
          _configurations.add(newConfig);
        }
      });

      await _saveConfigurations();
      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Configuration updated' : 'Configuration added',
            ),
          ),
        );
      }
    }
  }

  void _editConfiguration(int index) {
    final config = _configurations[index];
    setState(() {
      _nameController.text = config.name;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _hostController.text = config.host;
      _portController.text = config.port;
      _databaseController.text = config.database;
      _isEditing = true;
      _editingIndex = index;
    });
  }

  Future<void> _deleteConfiguration(int index) async {
    setState(() {
      _configurations.removeAt(index);
    });
    await _saveConfigurations();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuration deleted')));
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _hostController.clear();
    _portController.clear();
    _databaseController.clear();
    setState(() {
      _isEditing = false;
      _editingIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Server'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'Enter configuration name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'Enter database username',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter username';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter database password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            hintText: 'Enter database host',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter host';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '5432',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final port = int.tryParse(value);
                              if (port == null || port <= 0 || port > 65535) {
                                return 'Please enter a valid port number (1-65535)';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _databaseController,
                          decoration: const InputDecoration(
                            labelText: 'Database',
                            hintText: 'Enter database name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter database name';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _addConfiguration,
                        child: Text(_isEditing ? 'Update' : 'Add'),
                      ),
                      if (_isEditing)
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Saved Configurations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _configurations.length,
                itemBuilder: (context, index) {
                  final config = _configurations[index];
                  return Card(
                    child: ListTile(
                      title: Text(config.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Username: ${config.username}'),
                          Text('Host: ${config.host}:${config.port}'),
                          Text('Database: ${config.database}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editConfiguration(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteConfiguration(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
