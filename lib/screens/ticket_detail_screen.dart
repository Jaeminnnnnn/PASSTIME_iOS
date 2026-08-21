import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:marquee/marquee.dart';
import 'package:flutter/rendering.dart';
import 'package:passtime/menu/request_refund.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:passtime/map_view_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final bool readOnly;
  final String? eventStatus;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.readOnly = false,
    this.eventStatus,
  });

  @override
  _TicketDetailScreenState createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final Dio _dio = Dio();
  Map<String, dynamic>? ticketData;
  bool isLoading = true;
  bool hasError = false;

  final GlobalKey _dottedLineKey = GlobalKey();
  double _dottedLineY = 0.0;

  @override
  void initState() {
    super.initState();
    fetchTicketDetail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCirclePosition();
    });
  }

  Future<void> fetchTicketDetail() async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/ticket/detail';
    setState(() {
      isLoading = true;
    });

    try {
      final response = await _dio.get(
        apiUrl,
        queryParameters: {'ticketId': widget.ticketId},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        setState(() {
          ticketData = response.data['result'];
          isLoading = false;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _updateCirclePosition());
      } else {
        throw Exception('Failed to load ticket details');
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  void _updateCirclePosition() {
    final RenderBox? box =
        _dottedLineKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final parentData = box.parentData as FlexParentData;
      final yPosition = parentData.offset.dy;

      if (yPosition > 0 && _dottedLineY != yPosition - 15) {
        setState(() {
          _dottedLineY = yPosition - 15;
        });
      }
    }
  }

  void _openMapView() {
    if (widget.readOnly) return;

    final kakaoPlace = ticketData?['kakaoPlace'] as Map<String, dynamic>?;

    final rawY =
        kakaoPlace?['y'] ?? ticketData?['y'] ?? ticketData?['latitude'];
    final rawX =
        kakaoPlace?['x'] ?? ticketData?['x'] ?? ticketData?['longitude'];

    if (rawY == null || rawX == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지도 위치 정보를 불러올 수 없습니다.')),
      );
      return;
    }

    try {
      final double lat = double.parse(rawY.toString());
      final double lng = double.parse(rawX.toString());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapViewScreen(
            latitude: lat,
            longitude: lng,
            placeName: kakaoPlace?['place_name']?.toString() ??
                ticketData?['eventPlace']?.toString() ??
                ticketData?['eventTitle']?.toString(),
            addressName: kakaoPlace?['address_name']?.toString(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('좌표 파싱 에러: $e');
    }
  }

  Widget _buildKakaoMap() {
    final kakaoPlace = ticketData?['kakaoPlace'] as Map<String, dynamic>?;

    final rawY =
        kakaoPlace?['y'] ?? ticketData?['y'] ?? ticketData?['latitude'];
    final rawX =
        kakaoPlace?['x'] ?? ticketData?['x'] ?? ticketData?['longitude'];

    if (rawY == null || rawX == null) {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            "지도 정보를 불러올 수 없습니다.",
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    try {
      final double lat = double.parse(rawY.toString());
      final double lng = double.parse(rawX.toString());
      final LatLng position = LatLng(latitude: lat, longitude: lng);

      return KakaoMap(
        initialPosition: position,
        initialLevel: 17,
      );
    } catch (e) {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            "잘못된 지도 정보입니다.",
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateCirclePosition());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF334D61),
            size: 25,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.readOnly ? '참여 기록' : '입장권',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError || ticketData == null
              ? Align(
                  alignment: const Alignment(0.0, -0.15),
                  child: Text(
                    '입장권 유효기간이 만료되었습니다',
                    style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF334D61).withOpacity(0.5),
                        fontWeight: FontWeight.bold),
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: Column(
                      children: [
                        if (widget.readOnly) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF334D61).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      const Color(0xFF334D61).withOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                    color: const Color(0xFF334D61)
                                        .withOpacity(0.55),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '조회 전용 · 환불 및 지도 확대는 이용할 수 없습니다',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334D61)
                                            .withOpacity(0.7),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        Container(
                          margin: EdgeInsets.fromLTRB(
                            40,
                            widget.readOnly ? 12 : 40,
                            40,
                            40,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(20),
                            ),
                            border: widget.readOnly
                                ? Border.all(
                                    color: const Color(0xFF334D61)
                                        .withOpacity(0.12),
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              widget.readOnly ? "참여 행사" : "입장권",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: widget.readOnly
                                                    ? const Color(0xFF9E9E9E)
                                                    : Colors.black
                                                        .withOpacity(0.2),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (widget.readOnly &&
                                                widget.eventStatus != null &&
                                                widget.eventStatus!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF9E9E9E)
                                                            .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    widget.eventStatus!,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF9E9E9E),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          ticketData?["eventTitle"] ??
                                              "행사 제목 없음",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const Divider(
                                            height: 30,
                                            thickness: 1,
                                            color: Color(0xFFEEEDE3)),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "날짜",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      ticketData?["eventDay"] ??
                                                          "",
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const SizedBox(
                                              height: 30,
                                              child: VerticalDivider(
                                                color: Color(0xFFEEEDE3),
                                                thickness: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "시간",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      ticketData?[
                                                              "eventStartTime"] ??
                                                          "",
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(
                                            height: 30,
                                            thickness: 1,
                                            color: Color(0xFFEEEDE3)),
                                        Text(
                                            ticketData?["eventComment"] ??
                                                "관리자 행사 멘트 없음",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        const Divider(
                                            height: 30,
                                            thickness: 1,
                                            color: Color(0xFFEEEDE3)),
                                        Text(
                                          "장소 설명",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          height: 82,
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            ticketData?["eventPlaceComment"] ??
                                                "장소 설명 없음",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (!widget.readOnly)
                                          TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RequestRefundScreen(
                                                  initialTicketId:
                                                      widget.ticketId,
                                                ),
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF334D61)
                                                      .withOpacity(0.05),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              minimumSize: const Size(
                                                  double.infinity, 0),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                "취소/환불요청",
                                                style: TextStyle(
                                                    color: Color(0xFF334D61),
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    key: _dottedLineKey,
                                    height: 0,
                                    child: CustomPaint(
                                      painter: DottedLinePainter(),
                                      child: Container(),
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20),
                                    ),
                                    child: widget.readOnly
                                        ? Stack(
                                            children: [
                                              SizedBox(
                                                height: 200,
                                                width: double.infinity,
                                                child: ColorFiltered(
                                                  colorFilter: ColorFilter.mode(
                                                    Colors.grey
                                                        .withOpacity(0.35),
                                                    BlendMode.saturation,
                                                  ),
                                                  child: IgnorePointer(
                                                    child: _buildKakaoMap(),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 28,
                                                  color:
                                                      const Color(0xFF9E9E9E),
                                                  alignment: Alignment.center,
                                                  child: const Text(
                                                    '참여 기록은 조회만 가능합니다',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : SizedBox(
                                            height: 200,
                                            width: double.infinity,
                                            child: Stack(
                                              children: [
                                                SizedBox(
                                                  height: 200,
                                                  width: double.infinity,
                                                  child: IgnorePointer(
                                                    ignoring: true,
                                                    child: _buildKakaoMap(),
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
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.55),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text(
                                                      '탭하여 확대',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: double.infinity,
                                                    height: 23,
                                                    color:
                                                        const Color(0xFFC10230),
                                                    child: Marquee(
                                                      text:
                                                          "캡쳐하신 입장권은 사용할 수 없습니다.",
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                      scrollAxis:
                                                          Axis.horizontal,
                                                      blankSpace: 50.0,
                                                      velocity: 50.0,
                                                    ),
                                                  ),
                                                ),
                                                Positioned.fill(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: _openMapView,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              if (_dottedLineY > 0)
                                Positioned(
                                  left: -15,
                                  top: _dottedLineY,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF5F6F7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              if (_dottedLineY > 0)
                                Positioned(
                                  right: -15,
                                  top: _dottedLineY,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF5F6F7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 5;
    const double dashSpace = 5;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
