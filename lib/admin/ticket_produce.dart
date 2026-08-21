import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:passtime/admin/admin_ticket_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import '../place_search_screen.dart';
import 'package:passtime/map_picker_screen.dart';
import 'package:passtime/cookiejar_singleton.dart';
import 'package:passtime/utils/affiliation_api_parser.dart';

class TicketProduceScreen extends StatefulWidget {
  const TicketProduceScreen({super.key});

  @override
  _TicketProduceScreenState createState() => _TicketProduceScreenState();
}

class _TicketProduceScreenState extends State<TicketProduceScreen> {
  String? selectedDate;
  String? selectedStartTime;
  String? selectedAffiliation;
  List<String> affiliations = [];

  final picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _placeCommentController = TextEditingController();
  final TextEditingController _eventCommentController = TextEditingController();
  final TextEditingController _eventCodeController = TextEditingController();

  Map<String, dynamic>? _selectedPlace;
  KakaoMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _titleController.addListener(_updateButtonState);
    _placeCommentController.addListener(_updateButtonState);
    _eventCommentController.addListener(_updateButtonState);
    _eventCodeController.addListener(_updateButtonState);
  }

  Future<void> _initializeData() async {
    await _loadEnvVariables();
    await _fetchAffiliations();
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateButtonState);
    _placeCommentController.removeListener(_updateButtonState);
    _eventCommentController.removeListener(_updateButtonState);
    _eventCodeController.removeListener(_updateButtonState);
    _titleController.dispose();
    _placeCommentController.dispose();
    _eventCommentController.dispose();
    _eventCodeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadEnvVariables() async {
    await dotenv.load();
    debugPrint('API URL: ${dotenv.env['API_BASE_URL']}');
  }

  Future<void> _fetchAffiliations() async {
    final url =
        Uri.parse('${dotenv.env['API_BASE_URL']}/user/adminAffilliation/list');
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    try {
      final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
      final cookieHeader = cookies.isNotEmpty
          ? cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ')
          : '';

      final response = await http.get(
        url,
        headers: {'Cookie': cookieHeader},
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(utf8.decode(response.bodyBytes));
        final affiliationList =
            AffiliationApiParser.parseHostAffiliations(decodedResponse);

        if (affiliationList.isNotEmpty) {
          setState(() {
            affiliations = affiliationList
                .map<String>(
                    (item) => AffiliationApiParser.affiliationName(item))
                .toList();
          });
        }
      } else {
        debugPrint('소속 리스트를 불러오는 데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('네트워크 오류: $e');
    }
  }

  bool _isFormValid() {
    return selectedAffiliation != null &&
        _titleController.text.isNotEmpty &&
        selectedDate != null &&
        selectedStartTime != null &&
        _selectedPlace != null &&
        _placeCommentController.text.isNotEmpty &&
        _eventCommentController.text.isNotEmpty &&
        _eventCodeController.text.isNotEmpty;
  }

  void _updateButtonState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            toolbarHeight: 70,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.black,
                size: 30,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              '행사 제작',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              Divider(
                height: 2,
                thickness: 2,
                color: const Color(0xFF334D61).withOpacity(0.05),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAffiliationDropdown(),
                      const SizedBox(height: 14),
                      _buildInputField(
                          controller: _titleController,
                          label: "제목",
                          hintText: "제목 입력"),
                      const SizedBox(height: 14),
                      _buildDatePickerField(),
                      const SizedBox(height: 14),
                      _buildStartTimePickerField(),
                      const SizedBox(height: 14),
                      _buildPlaceSearchField(),
                      const SizedBox(height: 14),
                      _buildKakaoMap(),
                      const SizedBox(height: 14),
                      _buildInputField(
                          controller: _placeCommentController,
                          label: "장소 설명",
                          hintText: "장소 설명 입력"),
                      const SizedBox(height: 14),
                      _buildInputField(
                          controller: _eventCommentController,
                          label: "관리자 행사 멘트",
                          hintText: "관리자 행사 멘트 입력"),
                      const SizedBox(height: 14),
                      _buildInputField(
                          controller: _eventCodeController,
                          label: "행사 코드",
                          hintText: "행사 코드 입력"),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed:
                            _isFormValid() ? _showConfirmationDialog : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334D61),
                          disabledBackgroundColor:
                              const Color(0xFF334D61).withOpacity(0.3),
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withOpacity(0.7),
                        ),
                        child: const Text(
                          "완료",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKakaoMap() {
    Widget mapContent;
    if (_selectedPlace == null) {
      mapContent = Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF334D61).withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '장소를 선택하면 여기에 지도가 표시됩니다.',
            style: TextStyle(
                color: Colors.black.withOpacity(0.3),
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ),
      );
    } else {
      try {
        final double lat = double.parse(_selectedPlace!['y']);
        final double lng = double.parse(_selectedPlace!['x']);
        final LatLng position = LatLng(latitude: lat, longitude: lng);

        mapContent = SizedBox(
          height: 200,
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: KakaoMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialPosition: position,
                  initialLevel: 17,
                ),
              ),
              Positioned(
                top: 65,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/marker.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        mapContent = Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '장소의 좌표를 불러오는 데 실패했습니다.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openMapPicker,
      child: Stack(
        children: [
          mapContent,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '탭하여 직접 위치 조정',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapPicker() async {
    LatLng? initialPosition;
    String? initialPlaceName;
    String? initialAddress;

    if (_selectedPlace != null) {
      try {
        initialPosition = LatLng(
          latitude: double.parse(_selectedPlace!['y']),
          longitude: double.parse(_selectedPlace!['x']),
        );
        initialPlaceName = _selectedPlace!['place_name']?.toString();
        initialAddress = _selectedPlace!['address_name']?.toString();
      } catch (e) {
        debugPrint('초기 지도 위치 파싱 실패: $e');
      }
    }

    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialPosition: initialPosition,
          initialPlaceName: initialPlaceName,
          initialAddress: initialAddress,
        ),
      ),
    );

    if (selected != null) {
      _applySelectedPlace(selected);
    }
  }

  void _applySelectedPlace(Map<String, dynamic> selected) {
    setState(() {
      _selectedPlace = selected;
      _updateButtonState();
    });

    if (_mapController != null) {
      try {
        final double lat = double.parse(selected['y']);
        final double lng = double.parse(selected['x']);
        final newPosition = LatLng(latitude: lat, longitude: lng);
        _mapController!.moveCamera(
          cameraUpdate: CameraUpdate.fromLatLng(newPosition),
        );
      } catch (e) {
        debugPrint('카메라 이동 실패: $e');
      }
    }
  }

  void _showConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("행사를 제작하시겠습니까?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("확인", style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.pop(context);
              _createTicket();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliationDropdown() {
    final bool hasValue = selectedAffiliation != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61).withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "주최 소속",
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
                value: selectedAffiliation,
                hint: Text(
                  '주최 소속 선택',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.3),
                    fontSize: 16,
                  ),
                ),
                isExpanded: true,
                isDense: true,
                items: affiliations.map((affiliation) {
                  return DropdownMenuItem<String>(
                    value: affiliation,
                    child: Text(
                      affiliation,
                      style: const TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAffiliation = value;
                    _updateButtonState();
                  });
                },
                style: TextStyle(
                  color:
                      hasValue ? Colors.black : Colors.black.withOpacity(0.3),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceSearchField() {
    final bool hasValue = _selectedPlace != null;
    return GestureDetector(
      onTap: () async {
        final selected = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaceSearchScreen()),
        );

        if (selected != null) {
          _applySelectedPlace(selected);
        }
      },
      child: _buildDisplayField(
        label: "장소",
        displayText: _selectedPlace?['place_name'] ?? "장소 선택",
        icon: Icons.search_outlined,
        hasValue: hasValue,
      ),
    );
  }

  Future<void> _createTicket() async {
    if (!_isFormValid()) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("모든 필드를 채워주세요"),
          actions: [
            CupertinoDialogAction(
              child:
                  const Text("확인", style: TextStyle(color: Color(0xFFC10230))),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final url = Uri.parse('${dotenv.env['API_BASE_URL']}/ticket/createTicket');

    final body = {
      "eventTitle": _titleController.text,
      "eventDay": selectedDate!.substring(0, 10).replaceAll('.', '-'),
      "eventStartTime": selectedStartTime!,
      "eventEndTime": "",
      "eventPlace": _selectedPlace!['place_name'],
      "eventPlaceComment": _placeCommentController.text,
      "eventComment": _eventCommentController.text,
      "affiliation": selectedAffiliation,
      "eventCode": _eventCodeController.text,
      "kakaoPlace": {
        "place_name": _selectedPlace!['place_name'],
        "address_name": _selectedPlace!['address_name'],
        "x": _selectedPlace!['x'],
        "y": _selectedPlace!['y'],
      }
    };

    debugPrint('Sending data to server:');
    debugPrint(json.encode(body));

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final responseBody = utf8.decode(response.bodyBytes);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: $responseBody');

      final decodedResponse = json.decode(responseBody);

      if (decodedResponse['isSuccess'] == false &&
          decodedResponse['code'] == 'ERROR-0004') {
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("행사 코드 중복"),
            content: const Text("입력하신 행사 코드가 이미 존재합니다. 다른 코드를 사용해주세요."),
            actions: [
              CupertinoDialogAction(
                child: const Text("확인",
                    style: TextStyle(color: Color(0xFFC10230))),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Success response: $decodedResponse');

        if (!mounted) return;

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminTicketScreen()),
          );
        });
      } else {
        debugPrint(
            'Error: Server responded with status code ${response.statusCode}');
        if (!mounted) return;
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("행사 제작 실패"),
            content: Text(
                '오류가 발생했습니다: ${decodedResponse['message'] ?? response.statusCode}'),
            actions: [
              CupertinoDialogAction(
                child: const Text("확인",
                    style: TextStyle(color: Color(0xFFC10230))),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during ticket creation: $e');
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("네트워크 오류"),
          content: Text('행사 제작 중 오류가 발생했습니다: $e'),
          actions: [
            CupertinoDialogAction(
              child:
                  const Text("확인", style: TextStyle(color: Color(0xFFC10230))),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61).withOpacity(0.05),
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
            onChanged: (value) => _updateButtonState(),
            style: TextStyle(
              color: controller.text.isNotEmpty
                  ? Colors.black
                  : Colors.black.withOpacity(0.3),
              fontSize: 16,
            ),
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

  DateTime _parseSelectedDate() {
    if (selectedDate != null && selectedDate!.length >= 10) {
      final parts = selectedDate!.substring(0, 10).split('.');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime.now();
  }

  Future<DateTime?> _showStyledDatePicker(DateTime initialDate) async {
    const Color accent = Color(0xFFC10230);
    DateTime tempDate = initialDate;
    DateTime? result;

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
                        "날짜 선택",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () {
                          result = tempDate;
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
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initialDate,
                    minimumDate: DateTime(1900, 1, 1),
                    maximumDate: DateTime(2100, 1, 1),
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
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

  Widget _buildDatePickerField() {
    final bool hasValue = selectedDate != null;
    return GestureDetector(
      onTap: () async {
        final picked = await _showStyledDatePicker(_parseSelectedDate());
        if (picked != null) {
          setState(() {
            selectedDate =
                "${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}(${_getKoreanWeekday(picked.weekday)})";
            _updateButtonState();
          });
        }
      },
      child: _buildDisplayField(
        label: "날짜",
        displayText: selectedDate ?? "날짜 선택",
        icon: Icons.calendar_today_outlined,
        hasValue: hasValue,
      ),
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

  Widget _buildStartTimePickerField() {
    final bool hasValue = selectedStartTime != null;
    return GestureDetector(
      onTap: () async {
        final picked = await _showStyledTimePicker(
          _parseTimeOfDay(selectedStartTime),
        );
        if (picked != null) {
          setState(() {
            selectedStartTime =
                "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
            _updateButtonState();
          });
        }
      },
      child: _buildDisplayField(
        label: "시작 시간",
        displayText: selectedStartTime ?? "시작 시간 선택",
        icon: Icons.access_time_outlined,
        hasValue: hasValue,
      ),
    );
  }

  Widget _buildDisplayField({
    required String label,
    required String displayText,
    IconData? icon,
    required bool hasValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61).withOpacity(0.05),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color:
                        hasValue ? Colors.black : Colors.black.withOpacity(0.3),
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(icon ?? Icons.calendar_today_outlined,
                  color: Colors.grey, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  String _getKoreanWeekday(int weekday) {
    const weekdays = ["월", "화", "수", "목", "금", "토", "일"];
    return weekdays[weekday - 1];
  }
}
