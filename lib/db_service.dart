import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'config_page.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Future<List<Map<String, dynamic>>> getServerStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final configsJson = prefs.getStringList('configurations') ?? [];
    final configs = configsJson
        .map((json) => ConfigItem.fromJson(jsonDecode(json)))
        .toList();

    List<Map<String, dynamic>> statuses = [];

    for (var config in configs) {
      bool isConnected = false;
      String error = '';

      try {
        // Parse connection string to get components
        final uri = Uri.parse(config.connectionString);
        final userInfo = uri.userInfo.split(':');

        debugPrint('Host: ${uri.host}');
        debugPrint('Port: ${uri.port != 0 ? uri.port : 5432}');
        debugPrint('Database: ${uri.pathSegments.last}');
        debugPrint('Username: ${userInfo[0]}');
        debugPrint(
          'Password: ${userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : ''}',
        );

        final conn = await Connection.open(
          Endpoint(
            host: uri.host,
            port: uri.port != 0 ? uri.port : 5432,
            database: uri.pathSegments.last,
            username: userInfo[0],
            password: userInfo.length > 1
                ? Uri.decodeComponent(userInfo[1])
                : '',
          ),
          settings: ConnectionSettings(
            sslMode: SslMode.disable,
            connectTimeout: const Duration(seconds: 10),
          ),
        );

        // final results = await conn.execute('SELECT random_bool()');
        final results = await conn.execute('SELECT true');
        isConnected = results[0][0] as bool;

        await conn.close();
      } catch (e) {
        debugPrint("e: $e");
        error = e.toString();
        isConnected = false;
      }

      statuses.add({
        'name': config.name,
        'status': isConnected ? 'OK' : 'FAIL',
        'error': error,
      });
    }

    return statuses;
  }
}
