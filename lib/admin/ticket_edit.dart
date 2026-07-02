import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:passtime/admin/admin_ticket_screen.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import '../place_search_screen.dart';
import 'package:passtime/map_picker_screen.dart';

class TicketEditScreen extends StatefulWidget {
  final String ticketId;

  const TicketEditScreen({super.key, required this.ticketId});

  @override
  State<TicketEditScreen> createState() => _TicketEditScreenState();
}

class _TicketEditScreenState extends State<TicketEditScreen> {
  String? selectedAffiliation;
  String? selectedDate;
  String? selectedStartTime;
  List<String> affiliations = [];

  final _titleController = TextEditingController();
  final _placeCommentController = TextEditingController();
  final _commentController = TextEditingController();
  final _codeController = TextEditingController();

  Map<String, dynamic>? _selectedPlace;
  File? _pickedImage;
  bool _isLoading = true;
  Map<String, dynamic>? _initialTicketData;
  KakaoMapController? _mapController; // 2. 지도 컨트롤러 변수 추가

  @override
  void initState() {
    super.initState();
    _fetchTicketDetail();
    _fetchAffiliations();

    _titleController.addListener(_updateButtonState);
    _placeCommentController.addListener(_updateButtonState);
    _commentController.addListener(_updateButtonState);
    _codeController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateButtonState);
    _placeCommentController.removeListener(_updateButtonState);
    _commentController.removeListener(_updateButtonState);
    _codeController.removeListener(_updateButtonState);
    _titleController.dispose();
    _placeCommentController.dispose();
    _commentController.dispose();
    _codeController.dispose();
    _mapController?.dispose(); // 컨트롤러 dispose 추가
    super.dispose();
  }

  Future<void> _fetchAffiliations() async {
    final url = Uri.parse('${dotenv.env['API_BASE_URL']}/affiliation/List');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decodedResponse = json.decode(utf8.decode(response.bodyBytes));
        if (decodedResponse['isSuccess'] == true) {
          final List<dynamic> affiliationList = decodedResponse['result'];
          setState(() {
            affiliations = affiliationList
                .map<String>((item) => item['name'] as String)
                .toList();
          });
        }
      } else {
        debugPrint('Failed to load affiliations: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network error: $e');
    }
  }

  Future<void> _fetchTicketDetail() async {
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/ticket/modifyTicketDetail?ticketId=${widget.ticketId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final result = data['result'];

      setState(() {
        _initialTicketData = Map.from(result);
        _titleController.text = result['eventTitle'] ?? '';
        selectedDate = result['eventDay'] != null
            ? _formatDateForDisplay(result['eventDay'])
            : null;
        selectedStartTime = result['eventStartTime'] != null
            ? _formatTimeForDisplay(result['eventStartTime'])
            : null;
        _selectedPlace = result['kakaoPlace'] != null
            ? {
                'place_name': result['kakaoPlace']['place_name'] ?? '',
                'address_name': result['kakaoPlace']['address_name'] ?? '',
                'x': result['kakaoPlace']['x'] ?? '',
                'y': result['kakaoPlace']['y'] ?? '',
              }
            : null;
        _placeCommentController.text = result['eventPlaceComment'] ?? '';
        _commentController.text = result['eventComment'] ?? '';
        selectedAffiliation = result['affiliation'] ?? '';
        _codeController.text = result['eventCode'] ?? '';
        _isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to load details: ${response.statusCode}")),
      );
    }
  }

  String _formatDateForDisplay(String date) {
    try {
      final dateTime = DateTime.parse(date);
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final weekday = _getKoreanWeekday(dateTime.weekday);
      return "$year.$month.$day($weekday)";
    } catch (e) {
      return date;
    }
  }

  String _formatTimeForDisplay(String time) {
    try {
      final parts = time.split(':');
      final hour = parts[0];
      final minute = parts[1];
      return "$hour:$minute";
    } catch (e) {
      return time;
    }
  }

  Future<void> _submit() async {
    final uri = Uri.parse('${dotenv.env['API_BASE_URL']}/ticket/modifyTicket');

    String? eventDay;
    if (selectedDate != null) {
      final dateParts = selectedDate!.split('(').first.split('.');
      eventDay = '${dateParts[0]}-${dateParts[1]}-${dateParts[2]}';
    }

    String? eventStartTime;
    if (selectedStartTime != null) {
      eventStartTime = '$selectedStartTime:00';
    }

    final body = {
      "eventTitle": _titleController.text,
      "eventDay": eventDay,
      "eventStartTime": eventStartTime,
      "eventEndTime": "",
      "eventPlace": _selectedPlace?['place_name'],
      "eventPlaceComment": _placeCommentController.text,
      "eventComment": _commentController.text,
      "affiliation": selectedAffiliation,
      "eventCode": _codeController.text,
      "_id": widget.ticketId,
      "kakaoPlace": _selectedPlace,
    };

    debugPrint('--- 서버 전송 데이터 ---');
    debugPrint(json.encode(body));
    debugPrint('--- 전송 데이터 끝 ---');

    try {
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("Success response: $responseBody");
        if (!mounted) return;

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("행사 수정 완료"),
            content: const Text("행사 정보가 성공적으로 수정되었습니다."),
            actions: [
              CupertinoDialogAction(
                child: const Text("확인",
                    style: TextStyle(color: Color(0xFFC10230))),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminTicketScreen()),
                  );
                },
              ),
            ],
          ),
        );
      } else {
        debugPrint("Error response: ${response.statusCode}");
        debugPrint("Error body: $responseBody");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("Exception: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("네트워크 오류")),
      );
    }
  }

  void _showConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("행사를 수정하시겠습니까?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("취소"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("확인", style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.pop(context);
              _submit();
            },
          ),
        ],
      ),
    );
  }

  bool _isFormValid() {
    if (_initialTicketData == null) {
      return false;
    }

    final currentData = {
      'eventTitle': _titleController.text,
      'eventDay': selectedDate,
      'eventStartTime': selectedStartTime,
      'eventPlace': _selectedPlace?['place_name'],
      'eventPlaceComment': _placeCommentController.text,
      'eventComment': _commentController.text,
      'affiliation': selectedAffiliation,
      'eventCode': _codeController.text,
      'kakaoPlace': _selectedPlace,
    };

    if (_pickedImage != null) {
      return true;
    }

    if (currentData['eventTitle'] != _initialTicketData!['eventTitle'])
      return true;
    if (_initialTicketData!['eventDay'] != null &&
        currentData['eventDay'] !=
            _formatDateForDisplay(_initialTicketData!['eventDay'])) return true;
    if (_initialTicketData!['eventStartTime'] != null &&
        currentData['eventStartTime'] !=
            _formatTimeForDisplay(_initialTicketData!['eventStartTime']))
      return true;
    if (currentData['eventPlace'] != _initialTicketData!['eventPlace'])
      return true;
    if (currentData['eventPlaceComment'] !=
        _initialTicketData!['eventPlaceComment']) return true;
    if (currentData['eventComment'] != _initialTicketData!['eventComment'])
      return true;
    if (currentData['affiliation'] != _initialTicketData!['affiliation'])
      return true;
    if (currentData['eventCode'] != _initialTicketData!['eventCode'])
      return true;
    if (currentData['kakaoPlace'] != null &&
        _initialTicketData!['kakaoPlace'] != null) {
      if (currentData['kakaoPlace']!['x'] !=
              _initialTicketData!['kakaoPlace']['x'] ||
          currentData['kakaoPlace']!['y'] !=
              _initialTicketData!['kakaoPlace']['y']) {
        return true;
      }
    } else if (currentData['kakaoPlace'] != null ||
        _initialTicketData!['kakaoPlace'] != null) {
      return true;
    }

    return false;
  }

  void _updateButtonState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _isFormValid();

    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
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
              '행사 수정',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
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
                          controller: _commentController,
                          label: "관리자 행사 멘트",
                          hintText: "관리자 행사 멘트 입력"),
                      const SizedBox(height: 14),
                      _buildInputField(
                          controller: _codeController,
                          label: "행사 코드",
                          hintText: "행사 코드 입력"),
                      const SizedBox(height: 14),
                      // ✅ 완료 버튼도 스크롤 안에 넣어서 고정 X
                      // 완료 버튼 padding
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          0,
                          0,
                          MediaQuery.of(context).viewPadding.bottom +
                              16, // 하단 안전 영역 + 여유 공간
                        ),
                        child: ElevatedButton(
                          onPressed: canSubmit ? _showConfirmationDialog : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canSubmit
                                ? const Color(0xFF334D61)
                                : const Color(0xFF334D61).withOpacity(0.3),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
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
                      )
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildKakaoMap() {
    Widget mapContent;
    if (_selectedPlace == null ||
        _selectedPlace!['y'] == null ||
        _selectedPlace!['x'] == null) {
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
              fontWeight: FontWeight.w600,
            ),
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
          child: const Center(child: Text('지도를 불러올 수 없습니다.')),
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
        debugPrint('Camera move failed: $e');
      }
    }
  }

  Widget _buildAffiliationDropdown() {
    final bool isAffiliationInList = affiliations.contains(selectedAffiliation);
    final String? dropdownValue =
        isAffiliationInList ? selectedAffiliation : null;

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
                value: dropdownValue,
                hint: Text(
                  selectedAffiliation ?? '주최 소속 선택',
                  style: TextStyle(
                    color: dropdownValue != null
                        ? Colors.black
                        : Colors.black.withOpacity(0.3),
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
                  color: dropdownValue != null
                      ? Colors.black
                      : Colors.black.withOpacity(0.3),
                  fontSize: 16,
                ),
              ),
            ),
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

  Widget _buildDatePickerField() {
    final bool hasValue = selectedDate != null && selectedDate!.isNotEmpty;
    return GestureDetector(
      onTap: () {
        DatePicker.showDatePicker(
          context,
          showTitleActions: true,
          minTime: DateTime(1900, 1, 1),
          maxTime: DateTime(2100, 1, 1),
          onConfirm: (date) {
            setState(() {
              selectedDate =
                  "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}(${_getKoreanWeekday(date.weekday)})";
              _updateButtonState();
            });
          },
          currentTime: DateTime.now(),
          locale: LocaleType.ko,
        );
      },
      child: _buildDisplayField(
        label: "날짜",
        displayText: selectedDate ?? "날짜 선택",
        icon: Icons.calendar_today_outlined,
        hasValue: hasValue,
      ),
    );
  }

  Widget _buildStartTimePickerField() {
    final bool hasValue =
        selectedStartTime != null && selectedStartTime!.isNotEmpty;
    return GestureDetector(
      onTap: () {
        DatePicker.showTimePicker(
          context,
          showTitleActions: true,
          showSecondsColumn: false,
          onConfirm: (date) {
            setState(() {
              selectedStartTime =
                  "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              _updateButtonState();
            });
          },
          currentTime: DateTime.now(),
          locale: LocaleType.ko,
        );
      },
      child: _buildDisplayField(
        label: "시작 시간",
        displayText: selectedStartTime ?? "시작 시간 선택",
        icon: Icons.access_time_outlined,
        hasValue: hasValue,
      ),
    );
  }

  // 5. 장소 선택 시 지도 카메라 이동 로직 추가
  Widget _buildPlaceSearchField() {
    final bool hasValue = _selectedPlace?['place_name'] != null &&
        _selectedPlace!['place_name'].isNotEmpty;
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

  Widget _buildDisplayField({
    required String label,
    required String displayText,
    IconData? icon,
    required bool hasValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
