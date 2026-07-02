import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:passtime/cookiejar_singleton.dart';

class AffiliationRequest {
  final String id;
  final String name;
  final String studentId;
  final String phone;
  final String affiliationName;
  final String requestType;
  final String requestTypeLabel;
  final String introduction;
  final String status;
  final String statusLabel;
  final String adminComment;

  AffiliationRequest({
    required this.id,
    required this.name,
    required this.studentId,
    required this.phone,
    required this.affiliationName,
    required this.requestType,
    required this.requestTypeLabel,
    required this.introduction,
    required this.status,
    required this.statusLabel,
    required this.adminComment,
  });

  factory AffiliationRequest.fromJson(Map<String, dynamic> json) {
    final requestType = json['requestType']?.toString() ??
        (json['createAffiliation'] == true ? 'create' : 'admin');

    return AffiliationRequest(
      id: (json['requestId'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      affiliationName: json['affiliationName']?.toString() ?? '',
      requestType: requestType,
      requestTypeLabel: json['requestTypeLabel']?.toString() ??
          (requestType == 'create' ? '소속 생성' : '임원 권한'),
      introduction: json['introduction']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      statusLabel: json['statusLabel']?.toString() ?? '',
      adminComment: json['adminComment']?.toString() ?? '',
    );
  }

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
}

class RequestAdminDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestAdminDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<RequestAdminDetailScreen> createState() =>
      _RequestAdminDetailScreenState();
}

class _RequestAdminDetailScreenState extends State<RequestAdminDetailScreen> {
  Future<AffiliationRequest>? _requestDetailFuture;
  bool _isSubmitting = false;
  bool _isApproveSelected = true;
  bool _initializedFromDetail = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requestDetailFuture = _fetchRequestDetails();
  }

  Future<String> _getCookieHeader(Uri uri) async {
    final cookies = await CookieJarSingleton().cookieJar.loadForRequest(uri);
    if (cookies.isEmpty) return '';
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<AffiliationRequest> _fetchRequestDetails() async {
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/affiliation/affiliationRequests/${widget.requestId}');
    final headers = {
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return AffiliationRequest.fromJson(
          Map<String, dynamic>.from(data['result'] as Map),
        );
      } else {
        throw Exception('상세 정보를 불러오는데 실패했습니다. (상태 코드: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('오류가 발생했습니다: $e');
    }
  }

  void _syncFromDetail(AffiliationRequest detail) {
    if (_initializedFromDetail) return;
    if (detail.isApproved) {
      _isApproveSelected = true;
    } else if (detail.isRejected) {
      _isApproveSelected = false;
      _commentController.text = detail.adminComment;
    }
    _initializedFromDetail = true;
  }

  void _showSubmitConfirmationDialog(AffiliationRequest detail) {
    final isApprove = _isApproveSelected;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isApprove ? '승인 확인' : '미승인 확인'),
        content: Text(
          isApprove
              ? '이 신청을 승인하시겠습니까?'
              : '이 신청을 미승인 처리하시겠습니까?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.pop(context);
              _submitRequest(detail);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest(AffiliationRequest detail) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isApproveSelected) {
        await _approveRequest();
      } else {
        await _denyRequest(detail);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _approveRequest() async {
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}/affiliation/approve?requestId=${widget.requestId}');
    final headers = {
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.post(url, headers: headers);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showResultDialog(
          title: '승인 완료',
          message: '성공적으로 승인되었습니다.',
          shouldPop: true,
        );
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          title: '승인 실패',
          message: errorData['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(
        title: '오류 발생',
        message: '요청 중 오류가 발생했습니다: $e',
      );
    }
  }

  Future<void> _denyRequest(AffiliationRequest detail) async {
    final endpoint = detail.requestType == 'create'
        ? '/affiliation/deny/create'
        : '/affiliation/deny/admin';
    final url = Uri.parse(
        '${dotenv.env['API_BASE_URL']}$endpoint?requestId=${widget.requestId}');
    final cookieHeader = await _getCookieHeader(url);
    final headers = {
      'Content-Type': 'application/json',
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    };
    final body = json.encode({
      'comment': _commentController.text.trim(),
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          title: '미승인 완료',
          message: data['message']?.toString() ?? '신청이 미승인 처리되었습니다.',
          shouldPop: true,
        );
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        _showResultDialog(
          title: '미승인 실패',
          message: errorData['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(
        title: '오류 발생',
        message: '요청 중 오류가 발생했습니다: $e',
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    bool shouldPop = false,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인', style: TextStyle(color: Color(0xFFC10230))),
            onPressed: () {
              Navigator.pop(dialogContext);
              if (shouldPop) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            "권한 신청 상세",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Divider(
              height: 2,
              thickness: 2,
              color: const Color(0xFF334D61).withOpacity(0.05),
            ),
            Expanded(
              child: FutureBuilder<AffiliationRequest>(
                future: _requestDetailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('오류: ${snapshot.error}',
                          textAlign: TextAlign.center),
                    ));
                  } else if (snapshot.hasData) {
                    final detail = snapshot.data!;
                    _syncFromDetail(detail);
                    final bool isProcessed =
                        detail.isApproved || detail.isRejected;

                    return Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoContainer(
                                    label: "신청 유형",
                                    value: detail.requestTypeLabel),
                                const SizedBox(height: 16),
                                _buildInfoContainer(
                                    label: "이름", value: detail.name),
                                const SizedBox(height: 16),
                                _buildInfoContainer(
                                    label: "학번", value: detail.studentId),
                                const SizedBox(height: 16),
                                _buildInfoContainer(
                                    label: "전화번호", value: detail.phone),
                                const SizedBox(height: 16),
                                _buildInfoContainer(
                                    label: "소속", value: detail.affiliationName),
                                if (detail.introduction.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildInfoContainer(
                                    label: "소속 소개",
                                    value: detail.introduction,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _buildInfoContainer(
                                  label: "상태",
                                  value: detail.statusLabel.isNotEmpty
                                      ? detail.statusLabel
                                      : detail.status,
                                ),
                                const SizedBox(height: 16),
                                _buildApprovalToggle(isProcessed: isProcessed),
                                if (!_isApproveSelected) ...[
                                  const SizedBox(height: 12),
                                  _buildCommentField(isProcessed: isProcessed),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildBottomSection(detail, isProcessed),
                        ),
                      ],
                    );
                  } else {
                    return const Center(child: Text('데이터가 없습니다.'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(AffiliationRequest detail, bool isProcessed) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 16 : 0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: isProcessed || _isSubmitting
                  ? null
                  : () => _showSubmitConfirmationDialog(detail),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334D61),
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
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      isProcessed
                          ? (detail.isApproved ? '승인됨' : '미승인됨')
                          : '제출',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalToggle({required bool isProcessed}) {
    return Row(
      children: [
        Expanded(
          child: _buildToggleButton(
            label: '미승인',
            isSelected: !_isApproveSelected,
            selectedColor: const Color(0xFF334D61),
            onPressed: isProcessed
                ? null
                : () {
                    setState(() {
                      _isApproveSelected = false;
                    });
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildToggleButton(
            label: '승인',
            isSelected: _isApproveSelected,
            selectedColor: const Color(0xFFC10230),
            onPressed: isProcessed
                ? null
                : () {
                    setState(() {
                      _isApproveSelected = true;
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? selectedColor : Colors.white,
        disabledBackgroundColor:
            isSelected ? selectedColor.withOpacity(0.3) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: isSelected ? selectedColor : const Color(0xFFE2E2E2),
          ),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: isSelected ? Colors.white : const Color(0xFF868686),
        disabledForegroundColor:
            isSelected ? Colors.white.withOpacity(0.7) : const Color(0xFF868686),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCommentField({required bool isProcessed}) {
    return TextField(
      controller: _commentController,
      enabled: !isProcessed,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: '미승인 사유 입력',
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFF334D61).withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: TextStyle(
        fontSize: 16,
        color: Colors.black.withOpacity(0.7),
      ),
    );
  }

  Widget _buildInfoContainer({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF334D61).withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
