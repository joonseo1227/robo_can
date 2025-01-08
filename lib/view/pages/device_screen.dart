import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:robo_can/view/pages/set_mbti_page.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.connection});

  final BluetoothConnection connection;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  StreamSubscription? _readSubscription;
  final List<String> _receivedInput = [];

  @override
  void initState() {
    _readSubscription = widget.connection.input?.listen((event) {
      if (mounted) {
        setState(() => _receivedInput.add(utf8.decode(event)));
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.connection.dispose();
    _readSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connection to ${widget.connection.address}"),
      ),
      body: AnimatedMeshGradient(
        colors: const [
          Color(0xFFAED1F4),
          Color(0xFFE3B7E8),
          Color(0xFFF2B6AF),
          Color(0xFFF4C6A6),
        ],
        options: AnimatedMeshGradientOptions(
          speed: 5, // 애니메이션 속도
          amplitude: 5, // 웨이브의 진폭
          frequency: 2, // 웨이브의 빈도
          grain: 0.05, // 그레인 효과
        ),
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: () {
                widget.connection.writeString("E");
              },
              child: const Text("E"),
            ),
            ElevatedButton(
              onPressed: () {
                widget.connection.writeString("I");
              },
              child: const Text("I"),
            ),
            ElevatedButton(
              onPressed: () {
                widget.connection.writeString("D");
              },
              child: const Text("D"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("set MBTI"),
            ),
          ],
        ),
      ),
    );
  }
}
