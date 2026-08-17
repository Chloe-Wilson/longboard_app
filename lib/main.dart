import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'src/home/pages/home_page.dart';
import 'src/home/helpers/color_scheme.dart';
import 'src/home/widgets/settings_provider.dart';

Future<File> initializeSettingsFile() async {
  final directory = await getApplicationDocumentsDirectory();
  
  final path = '${directory.path}/settings.json';
  final file = File(path);

  bool fileExists = await file.exists();

  if (!fileExists) {
    await file.create(recursive: true);
    await file.writeAsString('{"Green": 10, "Yellow": 15, "Orange": 20, "Red": 25, "Blue": 30, "Purple": 35}');
  }
  return file;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final file = await initializeSettingsFile();
  
  final settingsNotifier = SettingsNotifier(file);
  await settingsNotifier.loadSettings();

  runApp(
    ChangeNotifierProvider.value(
      value: settingsNotifier,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: myColorScheme,
        scaffoldBackgroundColor: myColorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: myColorScheme.primary,
          foregroundColor: myColorScheme.onPrimary,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: myColorScheme.surface,
          titleTextStyle: TextStyle(color: myColorScheme.onSurface, fontSize: 20.0),
          contentTextStyle: TextStyle(color: myColorScheme.onSurface, fontSize: 16.0),
        ),
      ),
      home: const MyHomePage(title: 'Chloe Longboard App'),
    );
  }
}
