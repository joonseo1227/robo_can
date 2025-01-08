import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:robo_can/config/color/color.dart';
import 'package:robo_can/view/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetMbtiPage extends StatefulWidget {
  const SetMbtiPage({super.key, required this.connection});

  final BluetoothConnection connection;

  @override
  State<SetMbtiPage> createState() => _SetMbtiPageState();
}

class _SetMbtiPageState extends State<SetMbtiPage> {
  String? select1;
  String? select2;
  String? select3;
  String? select4;

  String get selectedMBTI =>
      "${select1 ?? ''}${select2 ?? ''}${select3 ?? ''}${select4 ?? ''}";

  void _onSelect(String label) {
    setState(() {
      if (label == "E" || label == "I") {
        select1 = label;
      } else if (label == "N" || label == "S") {
        select2 = label;
      } else if (label == "T" || label == "F") {
        select3 = label;
      } else if (label == "P" || label == "J") {
        select4 = label;
      }
    });
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

  void _goToNextStep() {
    debugPrint("Selected MBTI: $selectedMBTI");
    saveMBTI(selectedMBTI);
    if (select1 == 'E') {
      _sendBluetoothCommand('E');
    } else {
      _sendBluetoothCommand('I');
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          selectedMBTI: selectedMBTI,
          connection: widget.connection,
        ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> saveMBTI(String mbti) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedMBTI', mbti);
  }

  Future<String?> getSavedMBTI() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedMBTI');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grey10,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            "MBTI를 선택하세요",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: black,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MBTIContainer(
                label: "E",
                isSelected: select1 == "E",
                onSelect: () => _onSelect("E"),
              ),
              const SizedBox(width: 32),
              MBTIContainer(
                label: "I",
                isSelected: select1 == "I",
                onSelect: () => _onSelect("I"),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MBTIContainer(
                label: "S",
                isSelected: select2 == "S",
                onSelect: () => _onSelect("S"),
              ),
              const SizedBox(width: 32),
              MBTIContainer(
                label: "N",
                isSelected: select2 == "N",
                onSelect: () => _onSelect("N"),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MBTIContainer(
                label: "T",
                isSelected: select3 == "T",
                onSelect: () => _onSelect("T"),
              ),
              const SizedBox(width: 32),
              MBTIContainer(
                label: "F",
                isSelected: select3 == "F",
                onSelect: () => _onSelect("F"),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MBTIContainer(
                label: "J",
                isSelected: select4 == "J",
                onSelect: () => _onSelect("J"),
              ),
              const SizedBox(width: 32),
              MBTIContainer(
                label: "P",
                isSelected: select4 == "P",
                onSelect: () => _onSelect("P"),
              ),
            ],
          ),
          TextButton(
            onPressed: _goToNextStep,
            style: ButtonStyle(
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              backgroundColor: MaterialStateProperty.all(
                (select1 != null &&
                        select2 != null &&
                        select3 != null &&
                        select4 != null)
                    ? black
                    : grey20,
              ),
            ),
            child: const SizedBox(
              width: 320,
              height: 64,
              child: Center(
                child: Text(
                  "확인",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MBTIContainer class remains unchanged
class MBTIContainer extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelect;

  const MBTIContainer({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isSelected ? black : Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isSelected ? grey20 : grey10,
              isSelected ? white : white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.transparent : grey80.withOpacity(0.1),
              spreadRadius: 4,
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: isSelected ? Colors.transparent : white.withOpacity(0.8),
              spreadRadius: 4,
              blurRadius: 8,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: isSelected ? black : grey20,
            ),
          ),
        ),
      ),
    );
  }
}
