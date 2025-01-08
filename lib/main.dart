import 'package:flutter/material.dart';
import 'package:robo_can/view/pages/bt_page.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0072de),
          primary: const Color(0xFF0072de),
        ),
        scaffoldBackgroundColor: const Color(0xffececee),
        dividerTheme: const DividerThemeData(
          color: Color(0xffd9d9dc),
          space: 0,
          indent: 72,
          endIndent: 20,
        ),
      ),
      home: const BTPage(),
    ),
  );
}
