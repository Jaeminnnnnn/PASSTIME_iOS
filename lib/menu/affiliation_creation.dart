import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../cookiejar_singleton.dart';
import 'package:passtime/menu/my_page_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class MaskedInputController extends TextEditingController {
  @override
  set value(TextEditingValue newValue) {
    String newText = newValue.text;
    String cleanText = newText.replaceAll(RegExp(r'[^0-9]'), '');
    String formattedText = _formatPhoneNumber(cleanText);

    super.value = newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatPhoneNumber(String text) {
    if (text.length <= 3) {
      return text;
    } else if (text.length <= 7) {
      return '${text.substring(0, 3)}-${text.substring(3)}';
    } else {
      return '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7, text.length)}';
    }
  }
}

class AffiliationCreationScreen extends StatefulWidget {
  final String hostName;
  final String studentId;

  const AffiliationCreationScreen({
    super.key,
    required this.hostName,
    required this.studentId,
  });

  @override
  State<AffiliationCreationScreen> createState() =>
      _AffiliationCreationScreenState();
}

class _AffiliationCreationScreenState extends State<AffiliationCreationScreen> {
  final TextEditingController _affiliationNameController =
      TextEditingController();
  final TextEditingController _introductionController = TextEditingController();
  late final TextEditingController _hostNameController;
  late final TextEditingController _studentIdController;
  final MaskedInputController _phoneNumberController = MaskedInputController();

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _hostNameController = TextEditingController(text: widget.hostName);
    _studentIdController = TextEditingController(text: widget.studentId);

    _affiliationNameController.addListener(_updateButtonState);
    _phoneNumberController.addListener(_updateButtonState);

    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies =
            await CookieJarSingleton().cookieJar.loadForRequest(uri);
        options.headers['Cookie'] = cookies.isNotEmpty
            ? cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ')
            : '';
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final responseCookies = response.headers['set-cookie'];
        if (responseCookies != null && responseCookies.isNotEmpty) {
          final parsedCookies = responseCookies
              .map((cookie) => Cookie.fromSetCookieValue(cookie.toString()))
              .toList();
          CookieJarSingleton().cookieJar.saveFromResponse(uri, parsedCookies);
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  void _updateButtonState() {
    setState(() {});
  }

  @override
  void dispose() {
    _affiliationNameController.removeListener(_updateButtonState);
    _phoneNumberController.removeListener(_updateButtonState);

    _affiliationNameController.dispose();
    _introductionController.dispose();
    _hostNameController.dispose();
    _studentIdController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitAffiliationRequest() async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/affiliation/request';

    final requestBody = {
      'phone': _phoneNumberController.text.trim(),
      'affiliationName': _affiliationNameController.text.trim(),
      'requestType': 'create',
      'introduction': _introductionController.text.trim(),
    };

    try {
      final response = await _dio.post(
        apiUrl,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.data['code'] == 'SUCCESS-0000') {
        final message = response.data['message']?.toString() ??
            '소속 생성 신청이 완료되었습니다.';
        _showSuccessDialog(message);
      } else {
        _showFailureDialog(
          '소속 생성 신청 실패',
          response.data['message']?.toString() ?? '신청에 실패했습니다.',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final String errorMessage =
            e.response?.data?['message'] ?? '서버에서 오류가 발생했습니다.';
        _showFailureDialog('신청 실패', errorMessage);
      } else {
        _showFailureDialog('네트워크 오류', '서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.');
      }
    } catch (e) {
      _showFailureDialog('오류', '알 수 없는 오류가 발생했습니다.');
    }
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('신청 완료'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyPageScreen(),
                ),
                (route) => false,
              );
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

  void _showFailureDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(color: Color(0xFFC10230)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFormValid = _affiliationNameController.text.trim().isNotEmpty &&
        _phoneNumberController.text.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;

        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('페이지를 나가시겠습니까?'),
              content: const Text('작성한 내용은 저장되지 않습니다.'),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('취소'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('나가기'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
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
              '소속 생성',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          backgroundColor: const Color(0xFFF5F6F7),
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).viewInsets.bottom,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFormGroup(
                          label: '소속명',
                          child: _buildInputField(
                            controller: _affiliationNameController,
                            hintText: '소속명 입력',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormGroup(
                          label: '소속장명',
                          child: _buildReadOnlyField(
                            text: _hostNameController.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormGroup(
                          label: '학번',
                          child: _buildReadOnlyField(
                            text: _studentIdController.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormGroup(
                          label: '전화번호',
                          child: _buildInputField(
                            controller: _phoneNumberController,
                            hintText: '전화번호 입력',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormGroup(
                          label: '소속 소개',
                          child: _buildInputField(
                            controller: _introductionController,
                            hintText: '소속 소개 입력 (선택)',
                            maxLines: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '새 소속을 생성하면 자동으로 소속장 권한이 부여됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      onPressed: isFormValid ? _submitAffiliationRequest : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC10230),
                        disabledBackgroundColor:
                            const Color(0xFFC10230).withOpacity(0.3),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: const Text(
                        '소속 생성 신청',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildFormGroup({
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: Colors.black.withOpacity(0.6))),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String text,
  }) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
