import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../cookiejar_singleton.dart';
import 'package:passtime/screens/ticket_screen.dart';

class AddTicketCodeScreen extends StatefulWidget {
  const AddTicketCodeScreen({super.key});

  @override
  _AddTicketCodeScreenState createState() => _AddTicketCodeScreenState();
}

class _AddTicketCodeScreenState extends State<AddTicketCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateButtonState);
    _controller.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _controller.text.trim().isNotEmpty;
    });
  }

  void _showAlertDialog(String title, String message,
      {VoidCallback? onConfirm}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm();
            },
            child: const Text(
              '확인',
              style: TextStyle(color: Color(0xFFC10230)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTicketCode(String eventCode) async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/ticket/add';
    final dio = Dio();
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');
    final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);

    final cookieHeader = cookies.isNotEmpty
        ? cookies.map((c) => '${c.name}=${c.value}').join('; ')
        : '';

    final requestBody = json.encode({'eventCode': eventCode});
    print('Request Body: $requestBody');

    try {
      final response = await dio.post(
        apiUrl,
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Cookie': cookieHeader,
          },
        ),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final responseBody = response.data;
        if (responseBody['isSuccess']) {
          if (mounted) {
            _showAlertDialog('완료', '입장권이 생성되었습니다!', onConfirm: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TicketScreen()),
              );
            });
          }
        } else {
          if (mounted) {
            // General error message for 200 but isSuccess is false
            _showAlertDialog('오류', '코드 입력이 잘못되었습니다.');
          }
        }
      }
    } on DioException catch (e) {
      print('Dio Error: ${e.response?.statusCode}');
      if (mounted) {
        if (e.response?.statusCode == 403) {
          _showAlertDialog('오류', '해당 소속이 아닙니다.');
        } else {
          _showAlertDialog('오류', '코드 입력이 잘못되었습니다.');
        }
      }
    } catch (e) {
      print('General Error: $e');
      if (mounted) {
        _showAlertDialog('오류', '코드 입력이 잘못되었습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFFF5F6F7),
          appBar: AppBar(
            toolbarHeight: 70,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF334D61),
                size: 30,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              'CODE로 추가',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC10230)
                                      .withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC10230)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.confirmation_number_rounded,
                                      size: 30,
                                      color: Color(0xFFC10230),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                '행사 코드로 추가',
                                style: TextStyle(
                                  color: Color(0xFF1F2D3A),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '발급받은 행사 코드를 입력하면\n입장권이 자동으로 추가됩니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.4),
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 36),
                              TextField(
                                controller: _controller,
                                textAlign: TextAlign.center,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Color(0xFF1F2D3A),
                                ),
                                decoration: InputDecoration(
                                  hintText: '코드 입력',
                                  hintStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.22),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: const Color(0xFF334D61)
                                          .withOpacity(0.15),
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Color(0xFFC10230),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 15,
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '행사 주최 측에서 안내받은 코드를 입력하세요.',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.35),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: _isButtonEnabled
                          ? () {
                              final eventCode = _controller.text.trim();
                              _addTicketCode(eventCode);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC10230),
                        disabledBackgroundColor:
                            const Color(0xFFC10230).withOpacity(0.3),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: const Text(
                        '입장권 추가',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
