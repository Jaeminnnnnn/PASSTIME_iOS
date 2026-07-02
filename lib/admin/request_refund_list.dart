import 'package:flutter/material.dart';
import 'package:passtime/widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:passtime/widgets/admin_menu_button.dart';
import 'package:passtime/cookiejar_singleton.dart';
import 'package:passtime/utils/affiliation_api_parser.dart';
import 'package:passtime/admin/admin_ticket_screen.dart';
import 'package:passtime/admin/request_refund_ticket_list_screen.dart';
import 'package:passtime/widgets/refund_event_card.dart';

class RequestRefundListScreen extends StatefulWidget {
  const RequestRefundListScreen({super.key});

  @override
  State<RequestRefundListScreen> createState() =>
      _RequestRefundListScreenState();
}

class _RequestRefundListScreenState extends State<RequestRefundListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<Map<String, dynamic>> _affiliations = [];
  final Map<String, List<Map<String, dynamic>>> _eventsByAffiliationId = {};
  bool _isAffiliationLoading = true;
  bool _isEventsLoading = true;
  String? _errorMessage;

  bool _readApproved(dynamic status) {
    if (status == true || status == 'TRUE') return true;
    if (status is String && status.toUpperCase() == 'TRUE') return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _fetchAffiliations();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {});
    }
  }

  Future<String> _getCookieHeader() async {
    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');
    final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
    if (cookies.isEmpty) return '';
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<void> _fetchAffiliations() async {
    final url =
        Uri.parse('${dotenv.env['API_BASE_URL']}/user/adminAffilliation/list');

    try {
      final cookieHeader = await _getCookieHeader();
      final response = await http.get(url, headers: {'Cookie': cookieHeader});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedAffiliations =
            AffiliationApiParser.parseHostAffiliations(data);

        if (fetchedAffiliations.isNotEmpty) {
          setState(() {
            _affiliations = fetchedAffiliations;
            _isAffiliationLoading = false;

            if (_affiliations.isNotEmpty) {
              _tabController =
                  TabController(length: _affiliations.length, vsync: this);
              _tabController!.addListener(_handleTabSelection);
            }
          });

          await _fetchEvents();
        } else {
          setState(() {
            _isAffiliationLoading = false;
            _isEventsLoading = false;
            _errorMessage = data is Map
                ? (data['message']?.toString() ?? '소속 목록을 불러오는데 실패했습니다.')
                : '소속 목록을 불러오는데 실패했습니다.';
          });
        }
      } else {
        setState(() {
          _isAffiliationLoading = false;
          _isEventsLoading = false;
          _errorMessage = "서버 오류: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isAffiliationLoading = false;
        _isEventsLoading = false;
        _errorMessage = "네트워크 오류: $e";
      });
    }
  }

  Future<Map<String, Map<String, int>>> _fetchRefundCounts(
      String affiliationId) async {
    final counts = <String, Map<String, int>>{};
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/refund/list?affiliationId=$affiliationId');

    try {
      final cookieHeader = await _getCookieHeader();
      final response = await http.get(url, headers: {'Cookie': cookieHeader});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['isSuccess'] == true && data['result'] is List) {
          for (final refund in data['result']) {
            if (refund is! Map) continue;

            final ticketId = refund['ticketId']?.toString();
            final eventName = refund['eventName']?.toString() ?? '';
            final key = (ticketId != null && ticketId.isNotEmpty)
                ? ticketId
                : eventName;
            if (key.isEmpty) continue;

            counts.putIfAbsent(key, () => {'total': 0, 'pending': 0});
            counts[key]!['total'] = counts[key]!['total']! + 1;
            if (!_readApproved(refund['refundPermissionStatus'])) {
              counts[key]!['pending'] = counts[key]!['pending']! + 1;
            }
          }
        }
      }
    } catch (_) {}

    return counts;
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isEventsLoading = true;
    });

    final url = Uri.parse('${dotenv.env['API_BASE_URL']}/ticket/manageList');

    try {
      final cookieHeader = await _getCookieHeader();
      final response = await http.get(url, headers: {'Cookie': cookieHeader});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['isSuccess'] == true) {
          final List<dynamic> result = data['result'] ?? [];
          final events = result.map((item) {
            return {
              'ticketId': item['_id']?.toString() ?? '',
              'title': item['eventTitle']?.toString() ?? '',
              'dateTime':
                  '${item['eventDay']} • ${item['eventStartTime'].toString().substring(0, 5)}',
              'location': item['eventPlace']?.toString() ?? '',
              'affiliation': item['affiliation']?.toString() ?? '',
            };
          }).toList();

          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final affiliation in _affiliations) {
            final affiliationId =
                AffiliationApiParser.affiliationId(affiliation) ?? '';
            final affiliationName =
                AffiliationApiParser.affiliationName(affiliation);

            final refundCounts = await _fetchRefundCounts(affiliationId);
            final affiliationEvents = events
                .where((event) => event['affiliation'] == affiliationName)
                .cast<Map<String, dynamic>>()
                .map((event) {
              final ticketId = event['ticketId'] as String;
              final title = event['title'] as String;
              final countByTicket = refundCounts[ticketId];
              final countByTitle = refundCounts[title];
              final total = countByTicket?['total'] ??
                  countByTitle?['total'] ??
                  0;
              final pending = countByTicket?['pending'] ??
                  countByTitle?['pending'] ??
                  0;

              return {
                ...event,
                'totalCount': total,
                'pendingCount': pending,
              };
            }).toList();

            grouped[affiliationId] = affiliationEvents;
          }

          setState(() {
            _eventsByAffiliationId
              ..clear()
              ..addAll(grouped);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEventsLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _eventsForAffiliation(String affiliationId) {
    return _eventsByAffiliationId[affiliationId] ?? [];
  }

  int _pendingForAffiliation(String affiliationId) {
    return _eventsForAffiliation(affiliationId)
        .fold<int>(0, (sum, e) => sum + (e['pendingCount'] as int? ?? 0));
  }

  Widget _buildAffiliationTab(String name, int count) {
    return Tab(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(name),
          if (count > 0)
            Positioned(
              right: -13,
              top: -6,
              child: _countBadge(count),
            ),
        ],
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 12),
      height: 12,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFC10230),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminTicketScreen()),
          (Route<dynamic> route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const CustomAppBar(
          title: "환불 신청 목록",
          isOrganizerMode: true,
        ),
        floatingActionButton: const AdminMenuButton(),
        body: _isAffiliationLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _affiliations.isEmpty
                    ? const Center(child: Text("관리 중인 소속이 없습니다."))
                    : Column(
                        children: [
                          Container(
                            color: Colors.white,
                            child: TabBar(
                              isScrollable: true,
                              controller: _tabController,
                              tabAlignment: TabAlignment.start,
                              tabs: _affiliations.map((affiliation) {
                                final affiliationId =
                                    AffiliationApiParser.affiliationId(
                                            affiliation) ??
                                        '';
                                return _buildAffiliationTab(
                                  AffiliationApiParser.affiliationName(
                                      affiliation),
                                  _pendingForAffiliation(affiliationId),
                                );
                              }).toList(),
                              labelColor: const Color(0xFFC10230),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: const Color(0xFFC10230),
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: _affiliations.map((affiliation) {
                                final affiliationId =
                                    AffiliationApiParser.affiliationId(
                                            affiliation) ??
                                        '';
                                return _buildEventList(affiliationId);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildEventList(String affiliationId) {
    final events = _eventsForAffiliation(affiliationId);

    if (_isEventsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (events.isEmpty) {
      return Center(
        child: Align(
          alignment: const Alignment(0.0, -0.15),
          child: Text(
            '진행 중인 행사가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF334D61).withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: _fetchEvents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < events.length - 1 ? 5 : 0),
            child: RefundEventCard(
              title: event['title'] as String,
              dateTime: event['dateTime'] as String,
              location: event['location'] as String,
              totalCount: event['totalCount'] as int,
              pendingCount: event['pendingCount'] as int,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestRefundTicketListScreen(
                      ticketId: event['ticketId'] as String,
                      affiliationId: affiliationId,
                      eventTitle: event['title'] as String,
                      affiliationName: event['affiliation'] as String? ?? '',
                    ),
                  ),
                ).then((_) => _fetchEvents());
              },
            ),
          );
        },
      ),
    );
  }
}
