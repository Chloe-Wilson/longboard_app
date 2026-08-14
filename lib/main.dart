import 'package:flutter/material.dart';

import 'src/home/pages/home_page.dart';
import 'src/home/helpers/color_scheme.dart';

void main() {
  runApp(const MyApp());
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
