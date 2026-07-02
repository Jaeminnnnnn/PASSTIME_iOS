import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';

class RequestRefundDetailScreen extends StatefulWidget {
  final String refundId;

  const RequestRefundDetailScreen({super.key, required this.refundId});

  @override
  State<RequestRefundDetailScreen> createState() =>
      _RequestRefundDetailScreenState();
}

class _RequestRefundDetailScreenState extends State<RequestRefundDetailScreen> {
  late Future<Map<String, dynamic>> refundDetail;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    refundDetail = fetchRefundDetail();
  }

  Future<Map<String, dynamic>> fetchRefundDetail() async {
    final String apiUrl = "${dotenv.env['API_BASE_URL']}/refund/detail";
    final response = await http.get(
      Uri.parse("$apiUrl?refundId=${widget.refundId}"),
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

  Future<void> _updateRefundStatus(bool approve) async {
    setState(() {
      isProcessing = true;
    });

    final String apiUrl = approve
        ? "${dotenv.env['API_BASE_URL']}/refund/permission"
        : "${dotenv.env['API_BASE_URL']}/refund/deny";
    final uri = Uri.parse("$apiUrl?refundId=${widget.refundId}");

    try {
      final response = await http.put(uri);
      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody["isSuccess"] == true) {
        setState(() {
          refundDetail = fetchRefundDetail(); // 상태 새로고침
        });

        if (context.mounted) {
          showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: Text(approve ? "승인 완료" : "미승인 처리 완료"),
              content: Text(
                approve ? "환불 요청이 승인되었습니다." : "환불 요청이 미승인 처리되었습니다.",
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    Navigator.of(context).pop(); // 알림창 닫기
                    Navigator.of(context).pop(true); // 이전 화면으로 true 전달
                  },
                  child: const Text("확인",
                      style: TextStyle(color: Color(0xFFC10230))),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(responseBody["message"] ?? "처리에 실패했습니다.");
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text("오류"),
            content: Text("상태 변경 중 오류 발생: $e"),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("확인",
                    style: TextStyle(color: Color(0xFFC10230))),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black, size: 30),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        centerTitle: true,
        title: const Text(
          '환불 신청 상세',
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
          final isApproved = data["refundPermissionStatus"] == true;
          String v(String key) => (data[key] ?? "").toString();

          // 하단 버튼 여백 계산
          final bottomInset = MediaQuery.of(context).viewPadding.bottom;
          final buttonBottomPadding =
              (bottomInset > 0 ? bottomInset : 16).toDouble();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusBadge(isApproved),
                      const SizedBox(height: 20),
                      _buildSection("신청자 정보", [
                        ["이름", v("name")],
                        ["학번", v("studentId")],
                        ["전화번호", v("phone")],
                      ]),
                      const SizedBox(height: 16),
                      _buildSection("환불 정보", [
                        ["행사", v("eventTitle")],
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
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, buttonBottomPadding),
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _updateRefundStatus(!isApproved),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproved
                          ? const Color(0xFFC10230)
                          : const Color(0xFF334D61),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isApproved ? "미승인" : "승인",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _accent = Color(0xFF334D61);

  Widget _buildStatusBadge(bool isApproved) {
    final Color color = isApproved ? const Color(0xFF2E7D32) : _accent;
    final String label = isApproved ? "승인 완료" : "승인 대기";
    final IconData icon =
        isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded;

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
            color: _accent.withOpacity(0.04),
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
