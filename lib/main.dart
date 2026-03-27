import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  runApp(const ExamApp());
}

class ExamSecurity {
  static const platform = MethodChannel('exam_channel');

  static Future<bool> isSupportedAAC() async {
    if (!Platform.isIOS) return false;

    final version = await platform.invokeMethod('getIOSVersion');
    return version >= 13.4;
  }

  static Future<void> startExam() async {
    final supported = await isSupportedAAC();

    if (supported) {
      try {
        await platform.invokeMethod('startAssessment');
      } on PlatformException catch (e) {
        final details = e.details;
        final detailsMap = details is Map ? details : const <dynamic, dynamic>{};
        final domain = detailsMap['domain']?.toString() ?? '';
        final nativeCode = detailsMap['code']?.toString() ?? '';

        final isAacUnknownFailure =
            e.code == 'START_FAILED' && domain == 'AEAssessmentErrorDomain' && nativeCode == '1';

        if (e.code == 'UNSUPPORTED_SIMULATOR' || e.code == 'UNSUPPORTED' || isAacUnknownFailure) {
          throw Exception('USE_GUIDED_ACCESS');
        }

        rethrow;
      }
    } else {
      throw Exception("USE_GUIDED_ACCESS");
    }
  }

  static Future<void> endExam() async {
    await platform.invokeMethod('endAssessment');
  }

  static Future<String> getAssessmentState() async {
    final state = await platform.invokeMethod<String>('getAssessmentState');
    return state ?? 'UNKNOWN';
  }
}

class ExamApp extends StatelessWidget {
  const ExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ExamPage(),
    );
  }
}

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final WebViewController _controller;

  static const platform = MethodChannel('exam_channel');

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ExamHandler',
        onMessageReceived: (message) {
          if (message.message == "START_EXAM") {
            handleStartExam();
          } else if (message.message == "END_EXAM") {
            endExamLock();
          }
        },
      )
      ..loadRequest(Uri.parse("https://uaps.persis.or.id/login"));
  }

  Future<void> handleStartExam() async {
    try {
      await ExamSecurity.startExam();
      final state = await ExamSecurity.getAssessmentState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AAC status: $state')),
      );
    } catch (e) {
      if (e.toString().contains("USE_GUIDED_ACCESS")) {
        showGuidedAccessDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AAC gagal: ${e.toString()}')),
        );
      }
    }
  }

  void showGuidedAccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Aktifkan Mode Ujian"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Perangkat Anda tidak mendukung auto-lock.\n\n"
              "Silakan aktifkan Guided Access:\n\n"
              "1. Buka Settings\n"
              "2. Accessibility\n"
              "3. Guided Access\n"
              "4. Aktifkan\n"
              "5. Triple click tombol power saat ujian",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Saya Sudah Aktifkan"),
          ),
        ],
      ),
    );
  }

  Future<void> endExamLock() async {
    try {
      await platform.invokeMethod('endAssessment');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AAC status: INACTIVE')),
      );
    } catch (e) {
      debugPrint("Error end: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exam Mode"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: handleStartExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Start"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: endExamLock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text("Submit"),
                ),
              ],
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}