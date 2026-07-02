import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:passtime/screens/ticket_screen.dart';
import '../cookiejar_singleton.dart';

// 전화번호 포맷팅을 위한 MaskedInputController 클래스
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

class SendPaymentScreen extends StatefulWidget {
  const SendPaymentScreen({super.key});

  @override
  _SendPaymentScreenState createState() => _SendPaymentScreenState();
}

class _SendPaymentScreenState extends State<SendPaymentScreen> {
  String selectedEvent = '';
  List<Map<String, dynamic>> tickets = [];
  String? selectedTicketId;

  final MaskedInputController phoneController = MaskedInputController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  File? _image;
  final picker = ImagePicker();

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _setupDio();
    _fetchTickets();
    _fetchUserInfo(); // ✅ 유저 정보 가져오기
  }

// ✅ 유저 정보 불러오기 함수
  Future<void> _fetchUserInfo() async {
    try {
      final response =
          await _dio.get("${dotenv.env['API_BASE_URL']}/user/mypage");

      if (response.data['code'] == "SUCCESS-0000") {
        final user = response.data['result'];

        setState(() {
          nameController.text = user['name'] ?? '';
          studentIdController.text = user['studentId'] ?? '';
          departmentController.text = user['major'] ?? '';
        });
      } else {
        debugPrint("유저 정보 불러오기 실패: ${response.data['message']}");
      }
    } catch (e) {
      debugPrint("유저 정보 불러오기 오류: $e");
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    departmentController.dispose();
    studentIdController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _setupDio() {
    final uri = Uri.parse(dotenv.env['API_BASE_URL']!);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies =
            await CookieJarSingleton().cookieJar.loadForRequest(uri);
        if (cookies.isNotEmpty) {
          options.headers[HttpHeaders.cookieHeader] = cookies
              .map((cookie) => '${cookie.name}=${cookie.value}')
              .join('; ');
        }
        handler.next(options);
      },
    ));
  }

  Future<void> _fetchTickets() async {
    try {
      final response =
          await _dio.get('${dotenv.env['API_BASE_URL']}/ticket/List');
      final List<dynamic> data = response.data['result'];
      setState(() {
        tickets = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('티켓 불러오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
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
              '납부 내역 보내기',
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputField(
                        controller: departmentController,
                        label: "학과",
                        hintText: "학과 입력",
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: studentIdController,
                        label: "학번",
                        hintText: "학번 입력",
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: nameController,
                        label: "이름",
                        hintText: "이름 입력",
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: phoneController,
                        label: "전화번호",
                        hintText: "전화번호 입력",
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _buildEventDropdown(),
                      const SizedBox(height: 14),
                      _buildImagePickerField(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16.0,
                    0,
                    16.0,
                    MediaQuery.of(context).viewPadding.bottom > 0 ? 16.0 : 0.0,
                  ),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed:
                          _isFormValid() ? _showConfirmationDialog : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC10230),
                        disabledBackgroundColor:
                            const Color(0xFFC10230).withOpacity(0.3),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: const Text(
                        '완료',
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

  bool _isFormValid() {
    return departmentController.text.isNotEmpty &&
        studentIdController.text.isNotEmpty &&
        nameController.text.isNotEmpty &&
        phoneController.text.isNotEmpty &&
        selectedEvent.isNotEmpty &&
        _image != null;
  }

  void _showConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('제출하시겠습니까?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '입력한 정보가 맞는지 확인해 주세요.\n확인 후 제출을 진행합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.of(context).pop();
              _submitPayment();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitPayment() async {
    try {
      final formData = FormData.fromMap({
        'ticketId': selectedTicketId,
        'phone': phoneController.text,
        'paymentPicture': await MultipartFile.fromFile(
          _image!.path,
          filename: _image!.path.split('/').last,
        ),
        'department': departmentController.text,
        'studentId': studentIdController.text,
        'name': nameController.text,
      });

      final response = await _dio.post(
        "${dotenv.env['API_BASE_URL']}/payment/post",
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      debugPrint('응답 코드: ${response.statusCode}');
      debugPrint('서버 응답: ${response.data}');

      if (response.data['isSuccess'] == true) {
        _showSubmissionSuccessDialog();
      } else {
        _showErrorDialog(response.data['message'] ?? '제출에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('서버 오류 발생: $e');
      _showErrorDialog('서버 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  void _showSubmissionSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('제출하였습니다'),
        content: const Text('납부 내역이 제출되었습니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TicketScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.3),
                fontSize: 16,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildEventDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "행사",
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.white),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTicketId,
                hint: Text(
                  '행사 선택',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.3),
                    fontSize: 16,
                  ),
                ),
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                items: tickets.map((ticket) {
                  return DropdownMenuItem<String>(
                    value: ticket['_id'],
                    child: Text(
                        "${ticket['eventTitle']} (${ticket['affiliation']})"), // ✅ 행사 + 소속
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTicketId = value;
                    selectedEvent = tickets.firstWhere(
                      (ticket) => ticket['_id'] == value,
                    )['eventTitle'];
                  });
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImagePickerField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "납부 내역 사진",
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '날짜, 받는 사람 이름, 금액이\n'
            '모두 보이는 송금·이체 화면 사진을 첨부해 주세요.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickImage,
            child: _image == null
                ? Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334D61).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: Color(0xFF334D61)),
                          SizedBox(width: 8),
                          Text("사진 첨부",
                              style: TextStyle(
                                  color: Color(0xFF334D61),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: 150, // 원하는 너비로 설정
                          height: 150, // 원하는 높이로 설정
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: 5,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _image = null;
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Color(0xFF7E929F), size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }
}
