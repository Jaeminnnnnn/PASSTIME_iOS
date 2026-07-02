import 'package:flutter/material.dart';
import 'package:passtime/widgets/accent_event_card_shell.dart';

class AdminTicketCard extends StatelessWidget {
  final String ticketId;
  final String title;
  final String dateTime;
  final String location;
  final String affiliation;
  final String eventCode;
  final int totalCount;
  final int pendingCount;
  final int refundPendingCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPaymentTap;
  final VoidCallback? onRefundTap;

  const AdminTicketCard({
    super.key,
    required this.ticketId,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.affiliation,
    required this.eventCode,
    required this.totalCount,
    required this.pendingCount,
    this.refundPendingCount = 0,
    required this.onEdit,
    required this.onDelete,
    this.onPaymentTap,
    this.onRefundTap,
  });

  static const _accentColor = Color(0xFF334D61);

  @override
  Widget build(BuildContext context) {
    return AccentEventCardShell(
      accentColor: _accentColor,
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF334D61),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: '수정',
                  color: const Color(0xFF7E929F),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  label: '삭제',
                  color: const Color(0xFFC10230),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$dateTime · $location',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.45),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '행사 코드  ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: eventCode.isNotEmpty ? eventCode : '-',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (refundPendingCount > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRefundTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '환불 승인 대기 $refundPendingCount명',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC10230),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFFC10230),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '주최 소속  ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: affiliation.isNotEmpty ? affiliation : '-',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onPaymentTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '총원 $totalCount명',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ),
                            TextSpan(
                              text: ' · ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ),
                            TextSpan(
                              text: '승인 필요 $pendingCount명',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: pendingCount > 0
                                    ? const Color(0xFFC10230)
                                    : Colors.black.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.black.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 57,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
