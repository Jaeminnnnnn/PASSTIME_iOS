import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:passtime/widgets/custom_app_bar.dart';
import 'package:passtime/widgets/ticket_card.dart';
import '../cookiejar_singleton.dart';
import 'package:passtime/widgets/menu_button.dart';
import 'package:flutter/services.dart';
import 'package:passtime/menu/send_payment.dart';
import 'package:passtime/menu/add_ticket_code.dart';
import 'package:passtime/menu/add_ticket_nfc.dart';
import 'package:passtime/menu/request_refund.dart';
import 'package:passtime/menu/my_page_screen.dart';
import 'package:passtime/screens/participated_events_screen.dart';
import 'package:passtime/utils/organizer_mode_navigation.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final Dio _dio = Dio();
  late Future<List<Map<String, dynamic>>> _ticketsFuture = fetchTickets();
  late Future<Map<String, int>?> _eventCountFuture = fetchEventCount();

  @override
  void initState() {
    super.initState();
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
    _ticketsFuture = fetchTickets();
    _eventCountFuture = fetchEventCount();
  }

  Future<Map<String, int>?> fetchEventCount() async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/user/mypage/events/count';
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    try {
      final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
      final cookieHeader = cookies.isNotEmpty
          ? cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ')
          : '';

      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Cookie': cookieHeader,
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final result = response.data['result'] as Map<String, dynamic>? ?? {};
        return {
          'participatedCount': result['participatedCount'] as int? ?? 0,
          'totalCount': result['totalCount'] as int? ?? 0,
          'pendingCount': result['pendingCount'] as int? ?? 0,
          'refundCount': result['refundCount'] as int? ?? 0,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTickets() async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/ticket/main';
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    try {
      final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
      final cookieHeader = cookies.isNotEmpty
          ? cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ')
          : '';

      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Cookie': cookieHeader,
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['isSuccess'] == true) {
          return List<Map<String, dynamic>>.from(data['result']);
        } else {
          throw Exception('No tickets found.');
        }
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load tickets: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '사용 가능':
        return const Color(0xFFC10230);
      case '사용 불가':
        return const Color(0xFF9E9E9E);
      case '환불중':
        return const Color(0xFF334D61);
      case '환불됨':
        return const Color(0xFF282727);
      case '만료됨':
        return const Color(0xFF282727);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  int _countByStatus(List<Map<String, dynamic>> tickets, String status) {
    return tickets.where((t) => t['status']?.toString() == status).length;
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    return TicketCard(
      ticketId: ticket['_id'],
      title: ticket['eventTitle'],
      dateTime: '${ticket['eventDay']} • ${ticket['eventStartTime']}',
      location: ticket['eventPlace'],
      affiliation: ticket['affiliation']?.toString() ?? '',
      status: '${ticket['status']}',
      statusColor: _getStatusColor(ticket['status']?.toString() ?? ''),
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> tickets) {
    final total = tickets.length;
    final usable = _countByStatus(tickets, '사용 가능');
    final pending = total - usable;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 입장권',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryChip(
                label: '보유',
                value: '$total장',
                highlight: false,
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: '사용 가능',
                value: '$usable장',
                highlight: true,
              ),
              if (pending > 0) ...[
                const SizedBox(width: 8),
                _buildSummaryChip(
                  label: '대기/기타',
                  value: '$pending장',
                  highlight: false,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required bool highlight,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFC10230).withOpacity(0.9)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationSection() {
    return FutureBuilder<Map<String, int>?>(
      future: _eventCountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 96,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF334D61).withOpacity(0.08),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final stats = snapshot.data;
        if (stats == null) return const SizedBox.shrink();

        final participated = stats['participatedCount'] ?? 0;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ParticipatedEventsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF334D61).withOpacity(0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC10230).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        color: Color(0xFFC10230),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '나의 참여 기록',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF334D61).withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '승인·종료된 행사 기준',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334D61).withOpacity(0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            participated > 0
                                ? '지금까지 $participated개 행사에 참여했어요'
                                : '아직 참여한 행사가 없어요',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334D61).withOpacity(0.65),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334D61),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$participated',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '개 행사',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: const Color(0xFF334D61).withOpacity(0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '바로가기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF334D61).withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.payments_outlined,
                label: '납부 내역 보내기',
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const SendPaymentScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.receipt_long_outlined,
                label: '환불 신청',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RequestRefundScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.confirmation_number_outlined,
                label: 'CODE로 추가',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTicketCodeScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.nfc,
                label: 'NFC로 추가',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTicketNfcScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.admin_panel_settings_outlined,
                label: '주최자 모드',
                onTap: () => navigateToOrganizerMode(context, _dio),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.person_outline_rounded,
                label: '마이페이지',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyPageScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: const Color(0xFF334D61)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334D61),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        _buildSummaryCard(const []),
        const SizedBox(height: 48),
        Icon(
          Icons.confirmation_number_outlined,
          size: 64,
          color: const Color(0xFF334D61).withOpacity(0.25),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '현재 발급된 입장권이 없습니다',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334D61),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '참여 예정인 행사가 있다면 납부 내역을 보내주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: const Color(0xFF334D61).withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 48),
        _buildParticipationSection(),
        const SizedBox(height: 28),
        _buildQuickActions(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTicketContent(List<Map<String, dynamic>> tickets) {
    final isHeroLayout = tickets.length <= 2;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        _buildSummaryCard(tickets),
        if (isHeroLayout) ...[
          SizedBox(height: tickets.length == 1 ? 24 : 16),
          for (int i = 0; i < tickets.length; i++) ...[
            _buildTicketCard(tickets[i]),
            if (i < tickets.length - 1) const SizedBox(height: 16),
          ],
          SizedBox(height: tickets.length == 1 ? 20 : 16),
        ] else ...[
          const SizedBox(height: 12),
          for (int i = 0; i < tickets.length; i++) ...[
            _buildTicketCard(tickets[i]),
            if (i < tickets.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
        ],
        _buildParticipationSection(),
        const SizedBox(height: 28),
        _buildQuickActions(),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) {
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('앱을 종료하시겠습니까?'),
        content: const Text('앱을 완전히 종료합니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            child: const Text('종료'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: _onPopInvoked,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F7),
        appBar: const CustomAppBar(title: '입장권'),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildEmptyState();
            }

            final tickets = snapshot.data ?? [];
            if (tickets.isEmpty) {
              return _buildEmptyState();
            }

            return _buildTicketContent(tickets);
          },
        ),
        floatingActionButton: const MenuButton(),
      ),
    );
  }
}
