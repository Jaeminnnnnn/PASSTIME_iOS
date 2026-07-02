import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:passtime/widgets/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passtime/widgets/menu_button.dart';
import 'package:passtime/widgets/settings_banner_ad.dart';
import 'package:passtime/services/donate_purchase_service.dart';
import '../cookiejar_singleton.dart';
import 'package:passtime/screens/login_screen.dart';
import 'package:passtime/screens/ticket_screen.dart'; // TicketScreen import 추가

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationOn = false; // 초기 상태를 false로 설정
  bool _isRoot = false;
  bool _isRootLoading = true;
  bool _isDonating = false;
  String _appVersion = '';
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _setupDio();
    _fetchNotificationStatus(); // ✅ 앱 시작 시 알림 상태를 불러오는 함수 호출
    _fetchRootStatus();
    _loadAppVersion();
    if (DonatePurchaseService.instance.isSupported) {
      DonatePurchaseService.instance.initialize();
    }
    DonatePurchaseService.instance.onFeedback = _showPurchaseFeedback;
  }

  @override
  void dispose() {
    if (DonatePurchaseService.instance.onFeedback == _showPurchaseFeedback) {
      DonatePurchaseService.instance.onFeedback = null;
    }
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _fetchRootStatus() async {
    final String? apiBaseUrl = dotenv.env['API_BASE_URL'];
    if (apiBaseUrl == null) {
      if (mounted) {
        setState(() => _isRootLoading = false);
      }
      return;
    }

    try {
      final response = await _dio.get('$apiBaseUrl/user/mypage');
      if (!mounted) return;

      if (response.data['code'] == 'SUCCESS-0000') {
        setState(() {
          _isRoot = response.data['result']?['root'] == true;
          _isRootLoading = false;
        });
      } else {
        setState(() => _isRootLoading = false);
      }
    } on DioException {
      if (mounted) {
        setState(() => _isRootLoading = false);
      }
    }
  }

  void _showPurchaseFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => _isDonating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleDonateTap() {
    if (_isDonating) return;
    _showDonateOptionSheet();
  }

  void _showDonateOptionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                '후원 방식 선택',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334D61),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PASSTIME 운영에 힘이 됩니다. 감사합니다!',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF334D61).withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              _buildDonateOption(
                icon: Icons.volunteer_activism_rounded,
                title: '일시불 후원',
                subtitle: '한 번만 후원해요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startDonate(subscription: false);
                },
              ),
              _buildDonateOption(
                icon: Icons.autorenew_rounded,
                title: '정기 구독 후원',
                subtitle: '매월 자동으로 후원해요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startDonate(subscription: true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFC10230).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFC10230), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334D61),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF334D61).withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFF334D61).withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDonate({required bool subscription}) async {
    setState(() => _isDonating = true);
    if (subscription) {
      await DonatePurchaseService.instance.buySubscription();
    } else {
      await DonatePurchaseService.instance.buyDonate();
    }
    if (mounted && _isDonating) {
      setState(() => _isDonating = false);
    }
  }

  void _setupDio() {
    final uri = Uri.parse(dotenv.env['API_BASE_URL']!);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cookies = await CookieJarSingleton().cookieJar.loadForRequest(
                uri,
              );
          if (cookies.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] = cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ');
          }
          handler.next(options);
        },
      ),
    );
  }

  // ✅ 서버에서 현재 알림 상태를 가져오는 함수
  Future<void> _fetchNotificationStatus() async {
    final String? apiBaseUrl = dotenv.env['API_BASE_URL'];
    if (apiBaseUrl == null) {
      print('.env 파일에 API_BASE_URL이 설정되지 않았습니다.');
      return;
    }

    final url = '$apiBaseUrl/user/setting/';

    try {
      final response = await _dio.get(url);

      if (response.data['code'] == 'SUCCESS-0000') {
        setState(() {
          isNotificationOn = response.data['notification'];
        });
        print('알림 상태 불러오기 성공: $isNotificationOn');
      } else {
        print('알림 상태 불러오기 실패: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('알림 상태 불러오기 중 네트워크 오류 발생: ${e.message}');
    }
  }

  Future<void> _toggleNotification(bool value) async {
    final String? apiBaseUrl = dotenv.env['API_BASE_URL'];
    if (apiBaseUrl == null) {
      print('.env 파일에 API_BASE_URL이 설정되지 않았습니다.');
      setState(() {
        isNotificationOn = !value;
      });
      return;
    }

    final url = '$apiBaseUrl/notification/toggle/';
    final requestBody = json.encode({'isNotificationOn': value});

    try {
      final response = await _dio.patch(
        url,
        data: requestBody,
        options: Options(contentType: 'application/json'),
      );

      if (response.statusCode == 200) {
        print('알림 상태가 성공적으로 업데이트되었습니다.');
      } else {
        print('알림 상태 업데이트 실패: ${response.statusCode}');
        setState(() {
          isNotificationOn = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정 변경에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } on DioException catch (e) {
      print('네트워크 오류 발생: ${e.message}');
      setState(() {
        isNotificationOn = !value;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다.')));
    }
  }

  // 문의사항 팝업을 표시하는 함수
  void _showInquiryDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("문의사항"),
          content: const Text(
            "궁금한 점이 있으신가요?\n아래로 문의해주세요. 📬\n\nsky900156@naver.com\njmyoon4339@sju.ac.kr",
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop(); // 팝업 닫기
              },
              child: const Text(
                "확인",
                style: TextStyle(color: Color(0xFFC10230)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("로그아웃"),
          content: const Text("로그아웃하시겠습니까?"),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("취소"),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Navigator.of(context).pop();
                await CookieJarSingleton().cookieJar.deleteAll();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isAutoLogin', false);
                await prefs.remove('password');
                _logout();
              },
              isDestructiveAction: true,
              child: const Text(
                "확인",
                style: TextStyle(color: Color(0xFFC10230)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope 위젯을 추가하여 뒤로가기 동작을 제어합니다.
    return PopScope(
      canPop: false, // 뒤로가기 동작을 가로챕니다.
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        // 뒤로가기 제스처가 발생하면 TicketScreen으로 돌아갑니다.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TicketScreen()),
          (Route<dynamic> route) => false,
        );
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: "설정"),
        backgroundColor: const Color(0xFFF5F6F7),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomTile(
                      title: '알림',
                      isSwitch: true,
                      switchValue: isNotificationOn,
                      onSwitchChanged: (value) {
                        setState(() {
                          isNotificationOn = value;
                        });
                        _toggleNotification(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showInquiryDialog,
                      child:
                          _buildCustomTile(title: '문의사항', showMoreIcon: true),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomTile(
                      title: '패치버전',
                      infoText: _appVersion.isEmpty ? '-' : _appVersion,
                    ),
                    if (_isRoot && !_isRootLoading) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _isDonating ? null : _handleDonateTap,
                        child: _buildCustomTile(
                          title: '후원하기',
                          showMoreIcon: true,
                          trailing: _isDonating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CupertinoActivityIndicator(
                                    radius: 10,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                    GestureDetector(
                      onTap: _showLogoutDialog,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Color(0xFFC10230),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SettingsBannerAd(),
          ],
        ),
        floatingActionButton: const MenuButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildCustomTile({
    required String title,
    String? infoText,
    bool isSwitch = false,
    bool showMoreIcon = false,
    bool switchValue = false,
    Function(bool)? onSwitchChanged,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16.0, color: Colors.black),
          ),
          if (isSwitch)
            CupertinoSwitch(
              value: switchValue,
              onChanged: onSwitchChanged,
              activeTrackColor: const Color(0xFFC10230),
            )
          else if (showMoreIcon)
            trailing ??
                Icon(
                  Icons.more_horiz_rounded,
                  color: const Color(0xFF334D61).withOpacity(0.6),
                )
          else if (infoText != null)
            Text(
              infoText,
              style: TextStyle(
                fontSize: 16.0,
                color: const Color(0xFF334D61).withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }
}
