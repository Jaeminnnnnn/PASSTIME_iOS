import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:passtime/screens/ticket_screen.dart';
import '../cookiejar_singleton.dart';

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
    if (text.length <= 3) return text;
    if (text.length <= 7) return '${text.substring(0, 3)}-${text.substring(3)}';
    if (text.length <= 11)
      return '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7)}';
    return '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7, 11)}';
  }
}

class RequestRefundScreen extends StatefulWidget {
  final String? initialTicketId;

  const RequestRefundScreen({super.key, this.initialTicketId});

  @override
  _RequestRefundScreenState createState() => _RequestRefundScreenState();
}

class _RequestRefundScreenState extends State<RequestRefundScreen> {
  String? selectedDate;
  String? selectedTime;
  String? selectedTicketId;
  List<Map<String, dynamic>> tickets = [];

  final TextEditingController refundReasonController = TextEditingController();
  final MaskedInputController phoneNumberController = MaskedInputController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _setupDio();
    _fetchTickets();
    refundReasonController.addListener(_updateButtonState);
    phoneNumberController.addListener(_updateButtonState);
    bankNameController.addListener(_updateButtonState);
    accountNumberController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    refundReasonController.removeListener(_updateButtonState);
    phoneNumberController.removeListener(_updateButtonState);
    bankNameController.removeListener(_updateButtonState);
    accountNumberController.removeListener(_updateButtonState);
    refundReasonController.dispose();
    phoneNumberController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    super.dispose();
  }

  void _updateButtonState() => setState(() {});

  void _setupDio() {
    final uri = Uri.parse(dotenv.env['API_BASE_URL']!);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies =
            await CookieJarSingleton().cookieJar.loadForRequest(uri);
        if (cookies.isNotEmpty) {
          options.headers[HttpHeaders.cookieHeader] =
              cookies.map((c) => '${c.name}=${c.value}').join('; ');
        }
        handler.next(options);
      },
    ));
  }

  Future<void> _fetchTickets() async {
    try {
      final response =
          await _dio.get('${dotenv.env['API_BASE_URL']}/ticket/main');
      final List<dynamic> data = response.data['result'];
      final fetchedTickets = data.cast<Map<String, dynamic>>();
      setState(() {
        tickets = fetchedTickets;
        if (widget.initialTicketId != null) {
          final hasTicket = fetchedTickets.any(
            (ticket) => ticket['_id'] == widget.initialTicketId,
          );
          if (hasTicket) {
            selectedTicketId = widget.initialTicketId;
          }
        }
      });
    } catch (e) {
      debugPrint('티켓 불러오기 실패: $e');
    }
  }

  Future<void> _submitRefundRequest() async {
    if (!_isFormValid()) {
      _showCupertinoDialog('알림', '모든 필드를 입력해주세요.');
      return;
    }

    final body = {
      "phone": phoneNumberController.text,
      "refundReason": refundReasonController.text,
      "bankName": bankNameController.text,
      "accountNumber": accountNumberController.text,
      "visitDate": selectedDate!,
      "visitTime": selectedTime!,
      "ticketId": selectedTicketId!,
    };

    try {
      final response = await _dio.post(
        '${dotenv.env['API_BASE_URL']}/refund/request',
        data: json.encode(body),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final result = response.data;
      if (result['isSuccess']) {
        _showCupertinoDialog('성공', '환불 요청이 완료되었습니다.', onConfirm: () {
          Navigator.of(context).pop();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TicketScreen()),
          );
        });
      } else {
        _showCupertinoDialog('오류', result['message'] ?? '오류가 발생했습니다.');
      }
    } catch (e) {
      _showCupertinoDialog('오류', '요청 중 오류 발생: $e');
    }
  }

  void _showCupertinoDialog(String title, String content,
      {VoidCallback? onConfirm}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: onConfirm ?? () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
          ),
        ],
      ),
    );
  }

  bool _isFormValid() {
    return selectedTicketId != null &&
        refundReasonController.text.isNotEmpty &&
        selectedDate != null &&
        selectedTime != null &&
        phoneNumberController.text.isNotEmpty &&
        bankNameController.text.isNotEmpty &&
        accountNumberController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 16;

    return GestureDetector(
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
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF334D61), size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: const Text(
            '환불 신청',
            style: TextStyle(
                color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
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
                    _buildEventDropdown(),
                    const SizedBox(height: 14),
                    _buildInputField(
                        controller: refundReasonController,
                        label: "환불 사유",
                        hintText: "환불 사유 입력"),
                    const SizedBox(height: 14),
                    _buildDatePickerField(),
                    const SizedBox(height: 14),
                    _buildTimePickerField(),
                    const SizedBox(height: 14),
                    _buildInputField(
                        controller: phoneNumberController,
                        label: "전화번호",
                        hintText: "전화번호 입력",
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _buildInputField(
                        controller: bankNameController,
                        label: "은행명",
                        hintText: "은행명 입력 (예: 국민은행)"),
                    const SizedBox(height: 14),
                    _buildInputField(
                        controller: accountNumberController,
                        label: "계좌번호",
                        hintText: "계좌번호 입력 ('-' 없이)",
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "입력하신 계좌로 환불되며, 경우에 따라 직접 수령이 필요할 수 있습니다.",
                        style: TextStyle(
                            color: const Color(0xFFC10230).withOpacity(0.5),
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  child: ElevatedButton(
                    onPressed: _isFormValid() ? _submitRefundRequest : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10230),
                      disabledBackgroundColor:
                          const Color(0xFFC10230).withOpacity(0.3),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                    ),
                    child: const Text("신청",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      {required TextEditingController controller,
      required String label,
      required String hintText,
      TextInputType keyboardType = TextInputType.text}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.3), fontSize: 16),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none),
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
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("행사",
              style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.white),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTicketId,
                hint: Text('행사 선택',
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.3), fontSize: 16)),
                isExpanded: true,
                items: tickets.map((ticket) {
                  final affiliation = ticket['affiliation'] ?? '';
                  return DropdownMenuItem<String>(
                    value: ticket['_id'],
                    child: Text("${ticket['eventTitle']} ($affiliation)"),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedTicketId = value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseSelectedDate() {
    if (selectedDate != null) {
      final match =
          RegExp(r'(\d{4})\.(\d{2})\.(\d{2})').firstMatch(selectedDate!);
      if (match != null) {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      }
    }
    return DateTime.now();
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () async {
        const Color accent = Color(0xFFC10230);
        final picked = await showDatePicker(
          context: context,
          initialDate: _parseSelectedDate(),
          firstDate: DateTime(1900, 1, 1),
          lastDate: DateTime(2100, 1, 1),
          helpText: "방문 가능 날짜 선택",
          cancelText: "취소",
          confirmText: "확인",
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: accent,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
                dialogBackgroundColor: Colors.white,
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: accent),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            selectedDate =
                "${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}(${_getKoreanWeekday(picked.weekday)})";
          });
        }
      },
      child: _buildDisplayField(
          label: "방문 가능 날짜",
          displayText: selectedDate ?? "방문 가능 날짜 선택",
          icon: Icons.calendar_today_outlined),
    );
  }

  TimeOfDay _parseTimeOfDay(String? value) {
    if (value != null && value.contains(':')) {
      final parts = value.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return TimeOfDay.now();
  }

  Future<TimeOfDay?> _showStyledTimePicker(TimeOfDay initialTime) async {
    const Color accent = Color(0xFFC10230);
    int tempHour = initialTime.hour;
    int tempMinute = initialTime.minute;
    TimeOfDay? result;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "취소",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                      const Text(
                        "시간 선택",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () {
                          result = TimeOfDay(
                            hour: tempHour,
                            minute: tempMinute,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "확인",
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 70,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: tempHour,
                          ),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => tempHour = i,
                          children: List.generate(
                            24,
                            (i) => Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          ":",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: tempMinute,
                          ),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => tempMinute = i,
                          children: List.generate(
                            60,
                            (i) => Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }

  Widget _buildTimePickerField() {
    return GestureDetector(
      onTap: () async {
        final picked = await _showStyledTimePicker(
          _parseTimeOfDay(selectedTime),
        );
        if (picked != null) {
          setState(() {
            selectedTime =
                "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
          });
        }
      },
      child: _buildDisplayField(
          label: "방문 가능 시간",
          displayText: selectedTime ?? "방문 가능 시간 선택",
          icon: Icons.access_time_outlined),
    );
  }

  Widget _buildDisplayField(
      {required String label,
      required String displayText,
      String? suffixText,
      IconData? icon}) {
    final isHintText = displayText.contains("선택");
    final textColor = isHintText ? Colors.black.withOpacity(0.3) : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(displayText,
                      style: TextStyle(color: textColor, fontSize: 16))),
              if (icon != null) Icon(icon, color: Colors.grey, size: 20),
            ],
          ),
          if (suffixText != null) ...[
            const SizedBox(height: 5),
            Text(suffixText,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  String _getKoreanWeekday(int weekday) {
    const weekdays = ["월", "화", "수", "목", "금", "토", "일"];
    return weekdays[weekday - 1];
  }
}
