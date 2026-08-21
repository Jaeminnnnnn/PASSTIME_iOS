import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

class MapViewScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? placeName;
  final String? addressName;

  const MapViewScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.addressName,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  static const String _markerId = 'ticket_location';
  static const String _markerStyleId = 'ticket_marker_style';

  LatLng get _eventPosition => LatLng(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

  Future<void> _onMapCreated(KakaoMapController controller) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      // 1. assets/images/marker.png 파일에서 직접 PNG 바이트 데이터 로드
      final ByteData byteData =
          await rootBundle.load('assets/images/marker.png');
      final Uint8List rawBytes = byteData.buffer.asUint8List();

      // 2. targetWidth 지정을 통해 마커 크기 리사이징 (원하는 크기로 숫자를 변경하세요)
      final ui.Codec codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 80, // 마커의 너비 px 지정 (예: 50~70 사이 조정)
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? resizedByteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List resizedBytes = resizedByteData!.buffer.asUint8List();

      // 3. 축소된 마커 이미지 등록
      await controller.registerMarkerStyles(
        styles: [
          MarkerStyle(
            styleId: _markerStyleId,
            perLevels: [
              MarkerPerLevelStyle.fromBytes(bytes: resizedBytes),
            ],
          ),
        ],
      );

      await controller.addMarkerLayer(
        layerId: KakaoMapController.defaultLabelLayerId,
        zOrder: 1000,
        clickable: false,
      );

      await controller.addMarker(
        markerOption: MarkerOption(
          id: _markerId,
          latLng: _eventPosition,
          rank: 9999,
          styleId: _markerStyleId,
        ),
      );
    } catch (e) {
      debugPrint('마커 등록 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 70,
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black,
                size: 25,
              ),
            ),
          ),
          centerTitle: true,
          title: const Text(
            '행사 위치',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEDE3)),
            Expanded(
              child: KakaoMap(
                onMapCreated: _onMapCreated,
                initialPosition: _eventPosition,
                initialLevel: 17,
              ),
            ),
            if (widget.placeName != null || widget.addressName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEEEDE3))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.placeName != null &&
                        widget.placeName!.isNotEmpty) ...[
                      Text(
                        widget.placeName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (widget.addressName != null &&
                        widget.addressName!.isNotEmpty)
                      Text(
                        widget.addressName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
