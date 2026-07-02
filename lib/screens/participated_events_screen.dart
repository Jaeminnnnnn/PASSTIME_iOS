import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:passtime/cookiejar_singleton.dart';
import 'package:passtime/widgets/custom_app_bar.dart';
import 'package:passtime/widgets/menu_button.dart';
import 'package:passtime/widgets/ticket_card.dart';

class ParticipatedEventsScreen extends StatefulWidget {
  const ParticipatedEventsScreen({super.key});

  @override
  State<ParticipatedEventsScreen> createState() =>
      _ParticipatedEventsScreenState();
}

class _ParticipatedEventsScreenState extends State<ParticipatedEventsScreen> {
  final Dio _dio = Dio();
  late Future<List<Map<String, dynamic>>> _eventsFuture = fetchEvents();

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _monthLabels = [
    '1월',
    '2월',
    '3월',
    '4월',
    '5월',
    '6월',
    '7월',
    '8월',
    '9월',
    '10월',
    '11월',
    '12월',
  ];

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
      onError: (error, handler) => handler.next(error),
    ));

    _eventsFuture = fetchEvents();
  }

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final apiUrl = '${dotenv.env['API_BASE_URL']}/user/mypage/events';
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
        final events =
            List<Map<String, dynamic>>.from(response.data['result'] ?? []);
        if (events.isNotEmpty) {
          final latest = _parseEventDay(events.first['eventDay']?.toString());
          if (latest != null && mounted) {
            _focusedMonth = DateTime(latest.year, latest.month);
          }
        }
        return events;
      }
      return [];
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _eventsFuture = fetchEvents();
    });
    await _eventsFuture;
  }

  static DateTime? _parseEventDay(String? eventDay) {
    if (eventDay == null || eventDay.isEmpty) return null;
    final match = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})').firstMatch(eventDay);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Set<DateTime> _eventDates(List<Map<String, dynamic>> events) {
    return events
        .map((event) => _parseEventDay(event['eventDay']?.toString()))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
  }

  List<Map<String, dynamic>> _filteredEvents(
      List<Map<String, dynamic>> events) {
    if (_selectedDate == null) return events;
    return events.where((event) {
      final date = _parseEventDay(event['eventDay']?.toString());
      return date != null && _isSameDay(date, _selectedDate!);
    }).toList();
  }

  int _parseParticipantCount(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? '';
    final fromHistory = event['fromHistory'] == true;
    final startTime = event['eventStartTime']?.toString() ?? '';
    final endTime = event['eventEndTime']?.toString() ?? '';
    final timeRange =
        endTime.isNotEmpty ? '$startTime ~ $endTime' : startTime;

    return TicketCard(
      ticketId: event['ticketId']?.toString() ?? '',
      title: event['eventTitle']?.toString() ?? '',
      dateTime: '${event['eventDay']} • $timeRange',
      location: event['eventPlace']?.toString() ?? '',
      affiliation: event['affiliation']?.toString() ?? '',
      status: status,
      statusColor: const Color(0xFF9E9E9E),
      isParticipatedEvent: true,
      participantCount: _parseParticipantCount(event['participantCount']),
      isHistory: fromHistory,
    );
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> events) {
    final eventDates = _eventDates(events);
    final affiliations = events
        .map((event) => event['affiliation']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 참여 기록',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '지금까지 ${events.length}개 행사에 참여했어요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryChip(
                label: '참여 행사',
                value: '${events.length}개',
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: '참여 일수',
                value: '${eventDates.length}일',
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: '소속',
                value: '${affiliations.length}개',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(List<Map<String, dynamic>> events) {
    final eventDates = _eventDates(events);
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF334D61).withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF334D61),
                ),
              ),
              Expanded(
                child: Text(
                  '${_focusedMonth.year}년 ${_monthLabels[_focusedMonth.month - 1]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334D61),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF334D61),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: label == '일'
                              ? const Color(0xFFC10230)
                              : const Color(0xFF334D61).withOpacity(0.45),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();

              final day = index - startWeekday + 1;
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final hasEvent = eventDates.any((eventDate) =>
                  eventDate.year == date.year &&
                  eventDate.month == date.month &&
                  eventDate.day == date.day);
              final isSelected =
                  _selectedDate != null && _isSameDay(date, _selectedDate!);
              final isSunday = date.weekday == DateTime.sunday;

              return GestureDetector(
                onTap: hasEvent
                    ? () {
                        setState(() {
                          if (isSelected) {
                            _selectedDate = null;
                          } else {
                            _selectedDate = date;
                          }
                        });
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFC10230)
                        : hasEvent
                            ? const Color(0xFFC10230).withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              hasEvent ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isSunday
                                  ? const Color(0xFFC10230)
                                  : const Color(0xFF334D61),
                        ),
                      ),
                      if (hasEvent && !isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC10230),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedDate!.month}월 ${_selectedDate!.day}일 참여 행사',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334D61).withOpacity(0.7),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '전체 보기',
                    style: TextStyle(
                      color: Color(0xFFC10230),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '날짜를 탭하면 해당 날의 행사만 볼 수 있어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334D61).withOpacity(0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.event_busy_rounded,
          size: 64,
          color: const Color(0xFF334D61).withOpacity(0.25),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '참여한 행사가 없습니다',
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
            '승인된 행사와 종료된 행사만 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF334D61),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFilteredEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          '선택한 날짜에 참여한 행사가 없습니다',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334D61).withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: const CustomAppBar(title: '참여 행사'),
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _refreshEvents,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Text(
                      '목록을 불러오지 못했습니다',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334D61).withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              );
            }

            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return _buildEmptyState();
            }

            final filteredEvents = _filteredEvents(events);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildSummaryHeader(events),
                _buildCalendarCard(events),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _selectedDate == null
                        ? '전체 참여 행사'
                        : '${_selectedDate!.month}월 ${_selectedDate!.day}일 행사',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334D61),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (filteredEvents.isEmpty)
                  _buildFilteredEmptyState()
                else
                  ...filteredEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildEventCard(event),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: const MenuButton(),
    );
  }
}
