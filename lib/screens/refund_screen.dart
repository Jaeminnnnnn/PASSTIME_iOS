import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RefundScreen extends StatefulWidget {
  final String ticketId;

  const RefundScreen({super.key, required this.ticketId});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  late Future<Map<String, dynamic>> refundDetail;

  @override
  void initState() {
    super.initState();
    refundDetail = fetchRefundDetail();
  }

  Future<Map<String, dynamic>> fetchRefundDetail() async {
    final String apiUrl = "${dotenv.env['API_BASE_URL']}/ticket/refundDetail";
    final response = await http.get(
      Uri.parse("$apiUrl?ticketId=${widget.ticketId}"),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = json.decode(response.body);
      if (responseBody["isSuccess"] == true) {
        return responseBody["result"];
      } else {
        throw Exception("API 요청 실패: ${responseBody['message']}");
      }
    } else {
      throw Exception("서버 오류: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7), // 배경색 변경
      appBar: AppBar(
        // AppBar 스타일 변경
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
        title: const Text(
          '환불 상세 내역', // 제목은 원래 제목 유지
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: refundDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("오류 발생: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("데이터 없음"));
          }

          final data = snapshot.data!;
          String v(String key) => (data[key] ?? "").toString();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBadge(v("refundPermissionStatus")),
                const SizedBox(height: 20),
                _buildSection("신청자 정보", [
                  ["이름", v("name")],
                  ["학번", v("studentId")],
                  ["전화번호", v("phone")],
                ]),
                const SizedBox(height: 16),
                _buildSection("환불 정보", [
                  ["행사", v("eventName")],
                  ["환불 사유", v("refundReason")],
                ]),
                const SizedBox(height: 16),
                _buildSection("환불 계좌", [
                  ["은행명", v("bankName")],
                  ["계좌번호", v("accountNumber")],
                ]),
                const SizedBox(height: 16),
                _buildSection("방문 가능", [
                  ["날짜", v("visitDate")],
                  ["시간", v("visitTime")],
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _accent = Color(0xFF334D61);

  Widget _buildStatusBadge(String rawStatus) {
    final String status = rawStatus.trim();
    final bool isApproved = status == "true" ||
        status.contains("승인") ||
        status.contains("완료");

    final Color color = isApproved ? const Color(0xFF2E7D32) : _accent;
    final IconData icon =
        isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded;
    final String label = isApproved ? "환불 완료" : "환불 대기";

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<List<String>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _accent.withOpacity(0.55),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                _buildInfoRow(
                  rows[i][0],
                  rows[i][1],
                  showDivider: i != rows.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool showDivider = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.trim().isNotEmpty ? value : "-",
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: _accent.withOpacity(0.07),
          ),
      ],
    );
  }
}
