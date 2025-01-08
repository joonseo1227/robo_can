import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:robo_can/view/pages/bt_page.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../config/color/color.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.selectedMBTI,
    required this.connection,
    super.key,
  });

  final String selectedMBTI;
  final BluetoothConnection connection;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AudioPlayer audioPlayer = AudioPlayer();

  // Bluetooth related
  StreamSubscription? _readSubscription;
  final List<String> _receivedInput = [];

  // Voice recognition related
  PorcupineManager? _porcupineManager;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _recognizedText = "";

  // Overlay text display related
  bool _showOverlay = false;
  Timer? _overlayTimer;
  String _overlayText = "";
  double _overlayFontSize = 72.0;
  Color _overlayTextColor = Colors.white;
  Color _overlayBackgroundColor = Colors.black.withOpacity(0.7);
  String? _overlayImagePath;
  bool _showSpeechResult = false;

  Timer? _speechTimeout;

  @override
  void initState() {
    super.initState();
    _initializeBluetoothListener();
    _initializePorcupine();
  }

  void _initializeBluetoothListener() {
    _readSubscription = widget.connection.input?.listen(
      (event) {
        if (mounted) {
          setState(() => _receivedInput.add(utf8.decode(event)));
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('연결 오류: $error')),
          );
        }
      },
    );
  }

  Future<void> _requestPermissions() async {
    var microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) {
      microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        throw Exception("마이크 권한이 필요합니다.");
      }
    }
  }

  Future<void> _initializePorcupine() async {
    try {
      await _requestPermissions();

      const String keywordPath = "assets/wakewords/trash.ppn";
      const String modelPath = "assets/wakewords/porcupine_params_ko.pv";

      await dotenv.load(fileName: '.env');

      String? porcupineAPIKey = dotenv.env['PORCUPINE_API_KEY'];

      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        porcupineAPIKey!,
        [keywordPath],
        modelPath: modelPath,
        _wakeWordCallback,
      );

      await _porcupineManager?.start();
      debugPrint("Porcupine 초기화 성공 및 마이크 활성화!");
    } on PorcupineException catch (err) {
      debugPrint("Porcupine 초기화 중 에러 발생: $err");
    } catch (e) {
      debugPrint("알 수 없는 에러 발생: $e");
    }
  }

  void _wakeWordCallback(int keywordIndex) async {
    debugPrint("Wake Word 감지됨!");
    _sendBluetoothCommand('D');
    await _porcupineManager?.stop();
    _startSpeechRecognition();
  }

  void _startSpeechRecognition() async {
    if (await _speechToText.initialize()) {
      setState(() {
        _isListening = true;
        _recognizedText = "";
        _showSpeechResult = true;
      });

      _speechTimeout = Timer(const Duration(seconds: 6), () {
        debugPrint("음성 인식 타임아웃");
        _stopSpeechRecognition();
      });

      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          if (result.finalResult) {
            debugPrint("음성 인식 완료: ${result.recognizedWords}");
            _processVoiceCommand(result.recognizedWords);
            _stopSpeechRecognition();
          }
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
        ),
      );
    } else {
      debugPrint("음성 인식 초기화 실패");
    }
  }

  void _showOverlayText({
    required String text,
    Duration duration = const Duration(seconds: 10),
    double fontSize = 72.0,
    Color textColor = Colors.white,
    Color backgroundColor = const Color(0xB3000000),
    String? imagePath,
  }) {
    setState(() {
      _overlayText = text;
      _overlayFontSize = fontSize;
      _overlayTextColor = textColor;
      _overlayBackgroundColor = backgroundColor;
      _overlayImagePath = imagePath;
      _showOverlay = true;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(duration, _hideOverlay);
  }

  void _hideOverlay() {
    setState(() {
      _showOverlay = false;
      _overlayImagePath = null;
    });
    _overlayTimer?.cancel();
  }

  Future<void> _processVoiceCommand(String command) async {
    if (command.contains('안녕')) {
      _sendBluetoothCommand('H');
      _showOverlayText(
        text: "안녕하세요!",
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: Colors.green.withOpacity(0.7),
      );
    } else if (command.contains('시간') || command.contains('몇 시')) {
      _sendBluetoothCommand('T');
      final now = DateFormat('HH:mm').format(DateTime.now());
      _showOverlayText(
        text: now,
        duration: const Duration(seconds: 5),
      );
    } else if (command.contains('뒤로') || command.contains('빠꾸')) {
      _sendBluetoothCommand('B');
      _showOverlayText(
        text: "뒤로 갈게요",
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    } else if (command.contains('시작') || command.contains('다시')) {
      if (widget.selectedMBTI.contains('E')) {
        _sendBluetoothCommand('E');
      } else {
        _sendBluetoothCommand('I');
      }
    } else if (command.contains('멈춰') ||
        command.contains('정지') ||
        command.contains('그만')) {
      _sendBluetoothCommand('D');
      _showOverlayText(
        text: "멈출게요",
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: red60.withOpacity(0.5),
      );
    } else if (command.contains('크리스마스') ||
        command.contains('산타') ||
        command.contains('Santa tell me')) {
      _sendBluetoothCommand('M');
      _showOverlayText(
        text: "메리 크리스마스!",
        textColor: black,
        duration: const Duration(seconds: 10),
        fontSize: 72,
        backgroundColor: white.withOpacity(0.8),
        imagePath: 'assets/images/christmas.png',
      );
    } else if (command.contains('날씨') ||
        command.contains('비 와') ||
        command.contains('눈 와')) {
      _showOverlayText(
        text: "맑고 날씨가 추워요.",
        textColor: black,
        duration: const Duration(seconds: 5),
        fontSize: 72,
        backgroundColor: cyan20.withOpacity(0.9),
        imagePath: 'assets/images/sun.png',
      );
    } else if (command.contains('트월킹') ||
        command.contains('춤') ||
        command.contains('트월크') ||
        command.contains('스월킹')) {
      _sendBluetoothCommand('S');
    } else if (command.contains('도움말')) {
      _showOverlayText(
        text: "다음과 같이 말할 수 있어요:\n안녕, 시간, 시작, 뒤로, 멈춰, 크리스마스, 초기화, 트월킹, 너 누구야?",
        duration: const Duration(seconds: 8),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    } else if (command.contains('누구')) {
      _showOverlayText(
        text: "저는 쓰레기통입니다.",
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    } else if (command.contains('에스파') ||
        command.contains('수수수') ||
        command.contains('번호바') ||
        command.contains('슈퍼') ||
        command.contains('노바') ||
        command.contains('슈퍼')) {
      await audioPlayer.play(AssetSource("audios/supernova.MP3"));
      _showOverlayText(
        text: "수수수",
        duration: const Duration(seconds: 1),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
      await Future.delayed(const Duration(seconds: 1));
      _showOverlayText(
        text: "수퍼노바",
        duration: const Duration(seconds: 2),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    } else if (command.contains('안성윤') ||
        command.contains('로봇 공학') ||
        command.contains('성윤')) {
      _sendBluetoothCommand('H');
      _showOverlayText(
        text: "대 성 윤",
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    } else if (command.contains('초기화') || command.contains('처음으로')) {
      _sendBluetoothCommand('D');

      // 모든 리소스 정리
      _readSubscription?.cancel();
      _porcupineManager?.stop();
      _porcupineManager?.delete();
      _speechToText.stop();
      _overlayTimer?.cancel();
      widget.connection.dispose();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BTPage(),
        ),
        (Route<dynamic> route) => false,
      );
    } else {
      _showOverlayText(
        text: '이해하지 못했어요.\n "도움말"이라고 말해보세요.',
        duration: const Duration(seconds: 3),
        fontSize: 72,
        backgroundColor: black.withOpacity(0.5),
      );
    }
  }

  void _sendBluetoothCommand(String command) {
    try {
      widget.connection.writeString(command);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '명령이 전송되었습니다',
            style: TextStyle(
              color: black,
            ),
          ),
          backgroundColor: white,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('명령 전송 실패: $error')),
      );
    }
  }

  void _stopSpeechRecognition() async {
    _speechTimeout?.cancel();
    setState(() {
      _isListening = false;
      _showSpeechResult = false;
    });
    _speechToText.stop();
    debugPrint("음성 인식 종료. 핫워드 감지 재개.");

    // 조건에 따라 명령 전송
    if (_recognizedText.contains('시작') || _recognizedText.contains('다시')) {
      if (widget.selectedMBTI.contains('E')) {
        _sendBluetoothCommand('E');
      } else {
        _sendBluetoothCommand('I');
      }
    }

    await _porcupineManager?.start();
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    widget.connection.dispose();
    _porcupineManager?.stop();
    _porcupineManager?.delete();
    _speechToText.stop();
    _overlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedMeshGradient(
        colors: _isListening
            ? const [
                Color(0xFFF3FEFD),
                Color(0xFFB5FFE0),
                Color(0xFFE4FFE0),
                Color(0xFFD1F4FF),
              ]
            : widget.selectedMBTI.contains('E')
                ? const [
                    Color(0xFFAED1F4),
                    Color(0xFFE3B7E8),
                    Color(0xFFF2B6AF),
                    Color(0xFFF4C6A6),
                  ]
                : const [
                    Color(0xFFFFFACC),
                    Color(0xFFFFE99D),
                    Color(0xFFFFDBD5),
                    Color(0xFFFFC4A8),
                  ],
        options: AnimatedMeshGradientOptions(
          speed: 5,
          amplitude: 5,
          frequency: 2,
          grain: 0.05,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 32,
                ),
                Text(
                  '${widget.selectedMBTI}',
                  style: const TextStyle(
                    fontSize: 48,
                  ),
                ),
                const Spacer(),
                _isListening
                    ? const Text(
                        '듣고 있어요',
                        style: TextStyle(
                          fontSize: 24,
                          color: blue50,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text(
                        '"쓰레기"라고 부르기',
                        style: TextStyle(
                          fontSize: 24,
                          color: grey60,
                        ),
                      ),
                const SizedBox(
                  height: 16,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SuggestionContainer(
                        label: '몇 시야?',
                        onSelect: () {
                          _sendBluetoothCommand('T');
                          final now =
                              DateFormat('HH:mm').format(DateTime.now());
                          _showOverlayText(
                            text: now,
                            duration: const Duration(seconds: 5),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SuggestionContainer(
                        label: '뒤로 가',
                        onSelect: () {
                          _sendBluetoothCommand('B');
                        },
                      ),
                      const SizedBox(height: 16),
                      SuggestionContainer(
                        label: '멈춰',
                        onSelect: () {
                          _sendBluetoothCommand('D');
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  "${widget.connection.address}",
                  style: TextStyle(
                    color: black.withOpacity(
                      0.5,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 32,
                ),
              ],
            ),
            if (_showOverlay)
              Container(
                color: _overlayBackgroundColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_overlayImagePath != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Image.asset(
                            _overlayImagePath!,
                            width: 640,
                            height: 640,
                            fit: BoxFit.contain,
                          ),
                        ),
                      Text(
                        _overlayText,
                        style: TextStyle(
                          fontSize: _overlayFontSize,
                          fontWeight: FontWeight.bold,
                          color: _overlayTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (_showSpeechResult && _recognizedText.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _recognizedText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SuggestionContainer extends StatelessWidget {
  final String label;
  final VoidCallback onSelect;

  const SuggestionContainer({
    super.key,
    required this.label,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(64),
          color: white.withOpacity(0.6),
          boxShadow: [
            BoxShadow(
              color: grey80.withOpacity(0.1),
              spreadRadius: 4,
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: white.withOpacity(0.2),
              spreadRadius: 4,
              blurRadius: 8,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 32, 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.format_quote,
                color: grey60.withOpacity(0.2),
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  color: grey70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
