import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:passtime/cookiejar_singleton.dart';

class SendPaymentDetailScreen extends StatefulWidget {
  final String paymentId;

  const SendPaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<SendPaymentDetailScreen> createState() =>
      _SendPaymentDetailScreenState();
}

class _SendPaymentDetailScreenState extends State<SendPaymentDetailScreen> {
  late Future<Map<String, dynamic>> paymentDetail;
  bool isApproving = false;

  @override
  void initState() {
    super.initState();
    paymentDetail = fetchPaymentDetail();
  }

  Future<Map<String, dynamic>> fetchPaymentDetail() async {
    final String apiUrl = "${dotenv.env['API_BASE_URL']}/payment/detail";
    final uri = Uri.parse("$apiUrl?paymentId=${widget.paymentId}");
    final cookieHeader = await _getCookieHeader();

    final response = await http.get(uri, headers: {'Cookie': cookieHeader});

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

  Future<String> _getCookieHeader() async {
    final baseUri = Uri.parse(dotenv.env['API_BASE_URL'] ?? '');
    final cookies =
        await CookieJarSingleton().cookieJar.loadForRequest(baseUri);
    if (cookies.isEmpty) return '';
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<void> approvePayment(String paymentId) async {
    if (isApproving) return;

    setState(() {
      isApproving = true;
    });

    final String apiUrl = "${dotenv.env['API_BASE_URL']}/payment/permission";
    final uri = Uri.parse("$apiUrl?paymentId=$paymentId");

    try {
      final cookieHeader = await _getCookieHeader();
      final response = await http.put(
        uri,
        headers: {'Cookie': cookieHeader},
      );
      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 &&
          responseBody["isSuccess"] == true &&
          responseBody["result"]["paymentPermissionStatus"] == true) {
        if (context.mounted) {
          showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: const Text("승인 완료"),
              content: const Text("결제 승인이 완료되었습니다."),
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text("확인",
                      style: TextStyle(color: Color(0xFFC10230))),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(responseBody["message"] ?? "결제 승인에 실패했습니다. 다시 시도해주세요.");
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text("오류"),
            content: Text("승인 중 오류 발생: $e"),
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
          isApproving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final bottomPadding = (bottomInset > 0 ? bottomInset : 16).toDouble();

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
            '납부 내역 상세',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: paymentDetail,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("오류 발생: ${snapshot.error}"));
            } else if (!snapshot.hasData) {
              return const Center(child: Text("데이터 없음"));
            }

            final data = snapshot.data!;
            final isApproved = data["paymentPermissionStatus"] == true;
            final aiReviewStatus =
                data["aiReviewStatus"]?.toString() ?? 'none';
            final aiReview = data["aiReview"] as Map<String, dynamic>?;

            String v(String key) => (data[key] ?? "").toString();

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusBadge(isApproved),
                        const SizedBox(height: 20),
                        if (aiReviewStatus != 'none') ...[
                          _buildAiReviewSection(aiReviewStatus, aiReview),
                          const SizedBox(height: 20),
                        ],
                        _buildImageSection(data["paymentPicture"]),
                        const SizedBox(height: 20),
                        _buildSection("납부자 정보", [
                          ["이름", v("name")],
                          ["학번", v("studentId")],
                          ["전화번호", v("phone")],
                        ]),
                        const SizedBox(height: 16),
                        _buildSection("행사 정보", [
                          ["행사", v("eventTitle")],
                        ]),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton(
                      onPressed: (isApproved || isApproving)
                          ? null
                          : () => approvePayment(widget.paymentId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApproved
                            ? const Color(0xFFC10230)
                            : const Color(0xFF334D61),
                        disabledBackgroundColor:
                            const Color(0xFF334D61).withOpacity(0.3),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: isApproving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isApproved ? "승인됨" : "승인",
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
      ),
    );
  }

  Widget _buildAiReviewSection(
    String status,
    Map<String, dynamic>? aiReview,
  ) {
    late final String title;
    late final Color backgroundColor;
    late final Color textColor;

    switch (status) {
      case 'auto_approved':
        title = 'AI 자동 승인';
        backgroundColor = const Color(0xFF334D61);
        textColor = Colors.white;
        break;
      case 'suspicious':
        title = 'AI 의심 — 관리자 확인 필요';
        backgroundColor = const Color(0xFFFFE082);
        textColor = const Color(0xFF8D6E00);
        break;
      case 'failed':
        title = 'AI 검토 실패';
        backgroundColor = const Color(0xFFC10230).withOpacity(0.15);
        textColor = const Color(0xFFC10230);
        break;
      case 'reviewing':
        title = 'AI 검토 중';
        backgroundColor = const Color(0xFF334D61).withOpacity(0.1);
        textColor = const Color(0xFF334D61);
        break;
      default:
        return const SizedBox.shrink();
    }

    final reasons = aiReview?['reasons'] as List<dynamic>? ?? [];
    final extractedAmount = aiReview?['extractedAmount'];
    final extractedDate = aiReview?['extractedDate'];
    final extractedSender = aiReview?['extractedSenderName'];
    final extractedAccount = aiReview?['extractedAccountHolderName'];
    final confidence = aiReview?['combinedConfidence'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (aiReview != null) ...[
            const SizedBox(height: 10),
            if (extractedAmount != null)
              _buildAiInfoRow('추출 금액', '$extractedAmount원', textColor),
            if (extractedDate != null)
              _buildAiInfoRow('추출 날짜', extractedDate.toString(), textColor),
            if (extractedSender != null)
              _buildAiInfoRow('보낸 사람', extractedSender.toString(), textColor),
            if (extractedAccount != null)
              _buildAiInfoRow(
                '받는 사람',
                extractedAccount.toString(),
                textColor,
              ),
            if (confidence != null)
              _buildAiInfoRow(
                '신뢰도',
                '${(confidence is num ? confidence * 100 : double.tryParse(confidence.toString()) ?? 0).toStringAsFixed(1)}%',
                textColor,
              ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '사유',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            ...reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '· $reason',
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiInfoRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.85),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
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

  Widget _sectionTitle(String title) {
    return Padding(
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
    );
  }

  Widget _buildImageSection(String? imageUrl) {
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("납부 내역"),
        GestureDetector(
          onTap: hasImage ? () => _showFullImage(imageUrl) : null,
          child: Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withOpacity(0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stack) => Center(
                            child: Text(
                              "이미지를 불러올 수 없습니다",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded,
                                  size: 15, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                "크게 보기",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            size: 40, color: Colors.black.withOpacity(0.25)),
                        const SizedBox(height: 8),
                        Text(
                          "납부내역 사진 없음",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(dialogContext).padding.top + 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<List<String>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
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
