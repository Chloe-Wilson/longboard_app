import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class SettingsNotifier extends ChangeNotifier {
  final File _file;
  Map<String, dynamic> _settings = {};

  SettingsNotifier(this._file);

  Map<String, dynamic> get settings => _settings;

  Future<void> loadSettings() async {
    final contents = await _file.readAsString();
    _settings = jsonDecode(contents);
    notifyListeners();
  }

  Future<void> updateSetting(String key, int value) async {
    _settings[key] = value;
    await _file.writeAsString(jsonEncode(_settings));
    notifyListeners();
  }
}