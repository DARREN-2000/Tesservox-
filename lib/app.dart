import 'package:flutter/material.dart';

import 'ui/speak_page.dart';

class VaaniApp extends StatelessWidget {
  const VaaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaani',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      builder: (BuildContext context, Widget? child) {
        ErrorWidget.builder = (FlutterErrorDetails details) => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'An error occurred:\n\n${details.exception}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
        return child!;
      },
      home: const SpeakPage(),
    );
  }

  ThemeData _theme() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E7E)),
    );
    return base.copyWith(
      // Larger default text: many AAC users also have low vision, and
      // supporters are often reading over a shoulder from a metre away.
      textTheme: base.textTheme.apply(fontSizeFactor: 1.15),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );
  }
}
