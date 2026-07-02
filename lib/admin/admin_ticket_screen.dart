import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:passtime/widgets/custom_app_bar.dart';
import 'package:passtime/admin/ticket_edit.dart';
import 'package:passtime/widgets/admin_menu_button.dart';
import 'package:passtime/cookiejar_singleton.dart';
import 'package:passtime/utils/affiliation_api_parser.dart';
import 'package:passtime/widgets/admin_ticket_card.dart';
import 'package:passtime/admin/send_payment_ticket_list_screen.dart';
import 'package:passtime/admin/request_refund_ticket_list_screen.dart';
import 'package:passtime/screens/ticket_screen.dart';

class AdminTicketScreen extends StatefulWidget {
  const AdminTicketScreen({super.key});

  @override
  State<AdminTicketScreen> createState() => _AdminTicketScreenState();
}

class _AdminTicketScreenState extends State<AdminTicketScreen> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture = fetchTickets();
  List<Map<String, dynamic>> _affiliations = [];

  int _parseCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetchAffiliations();
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

      final response = await http.get(url, headers: {'Cookie': cookieHeader});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final affiliations = AffiliationApiParser.parseHostAffiliations(data);
        if (affiliations.isNotEmpty && mounted) {
          setState(() {
            _affiliations = affiliations;
          });
        }
      }
    } catch (_) {}
  }

  String? _findAffiliationId(String affiliationName) {
    for (final affiliation in _affiliations) {
      if (AffiliationApiParser.affiliationName(affiliation) == affiliationName) {
        return AffiliationApiParser.affiliationId(affiliation);
      }
    }
    return null;
  }

  Future<void> _navigateToPaymentList(Map<String, dynamic> ticket) async {
    if (_affiliations.isEmpty) {
      await _fetchAffiliations();
    }

    final affiliationName = ticket['affiliation']?.toString() ?? '';
    final affiliationId = _findAffiliationId(affiliationName);

    if (affiliationId == null || affiliationId.isEmpty) {
      showCupertinoErrorDialog('소속 정보를 찾을 수 없습니다.');
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendPaymentTicketListScreen(
          ticketId: ticket['ticketId']!.toString(),
          affiliationId: affiliationId,
          eventTitle: ticket['title']!.toString(),
          affiliationName: affiliationName,
        ),
      ),
    );
  }

  Future<void> _navigateToRefundList(Map<String, dynamic> ticket) async {
    if (_affiliations.isEmpty) {
      await _fetchAffiliations();
    }

    final affiliationName = ticket['affiliation']?.toString() ?? '';
    final affiliationId = _findAffiliationId(affiliationName);

    if (affiliationId == null || affiliationId.isEmpty) {
      showCupertinoErrorDialog('소속 정보를 찾을 수 없습니다.');
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestRefundTicketListScreen(
          ticketId: ticket['ticketId']!.toString(),
          affiliationId: affiliationId,
          eventTitle: ticket['title']!.toString(),
          affiliationName: affiliationName,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchTickets() async {
    final url = Uri.parse('${dotenv.env['API_BASE_URL']}/ticket/manageList');
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    try {
      final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
      final cookieHeader = cookies.isNotEmpty
          ? cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ')
          : '';

      final response = await http.get(
        url,
        headers: {
          'Cookie': cookieHeader,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['isSuccess'] == true) {
          final List<dynamic> result = data['result'];
          return result.map((item) {
            return {
              'ticketId': item['_id'],
              'title': item['eventTitle'],
              'dateTime':
                  '${item['eventDay']} • ${item['eventStartTime'].toString().substring(0, 5)}',
              'location': item['eventPlace'],
              'affiliation': item['affiliation']?.toString() ?? '',
              'eventCode': item['eventCode']?.toString() ?? '',
              'totalCount': _parseCount(item['totalCount']),
              'pendingCount': _parseCount(item['pendingCount']),
              'refundPendingCount': _parseCount(item['refundPendingCount']),
            };
          }).toList();
        } else {
          showCupertinoErrorDialog('데이터를 불러오는데 실패했습니다.');
          return [];
        }
      } else {
        showCupertinoErrorDialog('서버 응답 오류: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      showCupertinoErrorDialog('에러 발생: $e');
      return [];
    }
  }

  void showCupertinoErrorDialog(String message) {
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("알림"),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("확인"),
            ),
          ],
        ),
      );
    }
  }

  void showCupertinoSuccessDialog(String message) {
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("성공"),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child:
                  const Text("확인", style: TextStyle(color: Color(0xFFC10230))),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    final url = Uri.parse('${dotenv.env['API_BASE_URL']}/ticket/delete');
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');

    try {
      final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
      final cookieHeader = cookies.isNotEmpty
          ? cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ')
          : '';

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookieHeader,
        },
        body: json.encode({'ticketId': ticketId}),
      );

      final data = json.decode(response.body);
      if (data['isSuccess'] == true) {
        showCupertinoSuccessDialog('티켓이 성공적으로 삭제되었습니다.');
        setState(() {
          _ticketsFuture = fetchTickets();
        });
      } else {
        showCupertinoErrorDialog(data['message'] ?? '삭제 실패');
      }
    } catch (e) {
      showCupertinoErrorDialog('에러 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.white,
        appBar: const CustomAppBar(
          title: "행사 관리",
          isOrganizerMode: true,
        ),
        body: Column(
          children: [
            Divider(
              height: 2,
              thickness: 2,
              color: const Color(0xFF334D61).withOpacity(0.05),
            ),
            Expanded(
              child: RefreshIndicator(
                // RefreshIndicator UI를 TicketScreen과 동일하게 변경
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  setState(() {
                    _ticketsFuture = fetchTickets();
                  });
                },
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ticketsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      // 텍스트 스타일과 위치를 TicketScreen과 동일하게 변경
                      return Align(
                        alignment: const Alignment(0.0, -0.15),
                        child: Text(
                          '현재 진행중인 행사가 없습니다',
                          style: TextStyle(
                              fontSize: 16,
                              color: const Color(0xFF334D61).withOpacity(0.5),
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    } else {
                      final tickets = snapshot.data!;
                      return Padding(
                        // ListView 패딩을 TicketScreen과 동일하게 변경
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 0),
                        child: ListView.builder(
                          itemCount: tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = tickets[index];
                            return Padding(
                              padding:
                                  EdgeInsets.only(top: index == 0 ? 10.0 : 5.0),
                              child: AdminTicketCard(
                                ticketId: ticket['ticketId']!,
                                title: ticket['title']!,
                                dateTime: ticket['dateTime']!,
                                location: ticket['location']!,
                                affiliation: ticket['affiliation']!,
                                eventCode: ticket['eventCode']?.toString() ?? '',
                                totalCount: _parseCount(ticket['totalCount']),
                                pendingCount: _parseCount(ticket['pendingCount']),
                                refundPendingCount:
                                    _parseCount(ticket['refundPendingCount']),
                                onPaymentTap: () => _navigateToPaymentList(ticket),
                                onRefundTap: () => _navigateToRefundList(ticket),
                                onEdit: () async {
                                  final result = await Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => TicketEditScreen(
                                        ticketId: ticket['ticketId'],
                                      ),
                                    ),
                                  );
                                  if (result == 'modified') {
                                    setState(() {
                                      _ticketsFuture = fetchTickets();
                                    });
                                  }
                                },
                                onDelete: () async {
                                  final confirm =
                                      await showCupertinoDialog<bool>(
                                    context: context,
                                    builder: (context) => CupertinoAlertDialog(
                                      title: const Text("정말 삭제하시겠습니까?"),
                                      actions: [
                                        CupertinoDialogAction(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text("취소"),
                                        ),
                                        CupertinoDialogAction(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text("삭제",
                                              style: TextStyle(
                                                  color: Color(0xFFC10230))),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    _deleteTicket(ticket['ticketId']);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: const AdminMenuButton(),
      ),
    );
  }
}
