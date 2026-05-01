import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_text.dart';
import '../data/safety_repository.dart';

/// API/inceleme için tutarlı Türkçe sebep metni (değişmeden gider).
const _kReportReasonsTr = <String>[
  'Taciz veya nefret söylemi',
  'Spam veya dolandırıcılık',
  'Uygunsuz veya rahatsız edici içerik',
  'Diğer',
];

const _kReportReasonsEn = <String>[
  'Harassment or hate speech',
  'Spam or fraud',
  'Inappropriate or disturbing content',
  'Other',
];

Future<void> showReportUserSheet({
  required BuildContext context,
  required String sessionId,
  required String reportedUserId,
  String? peerLabel,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _ReportUserSheetBody(
          sessionId: sessionId,
          reportedUserId: reportedUserId,
          peerLabel: peerLabel,
        ),
      );
    },
  );
}

class _ReportUserSheetBody extends ConsumerStatefulWidget {
  const _ReportUserSheetBody({
    required this.sessionId,
    required this.reportedUserId,
    this.peerLabel,
  });

  final String sessionId;
  final String reportedUserId;
  final String? peerLabel;

  @override
  ConsumerState<_ReportUserSheetBody> createState() =>
      _ReportUserSheetBodyState();
}

class _ReportUserSheetBodyState extends ConsumerState<_ReportUserSheetBody> {
  String _reason = _kReportReasonsTr.first;
  final _detailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(safetyRepositoryProvider).submitReport(
            reportedUserId: widget.reportedUserId,
            sessionId: widget.sessionId,
            reason: _reason,
            description: _detailCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Şikayetin alındı. İnceleyeceğiz.',
              'Your report was received. We will review it.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.peerLabel ?? trEn(context, 'Kullanıcı', 'User');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trEn(context, 'Şikayet: $label', 'Report: $label'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: trEn(context, 'Sebep', 'Reason'),
                border: const OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reason,
                  isExpanded: true,
                  items: List.generate(
                    _kReportReasonsTr.length,
                    (i) {
                      final r = _kReportReasonsTr[i];
                      final display = trEn(
                        context,
                        r,
                        _kReportReasonsEn[i],
                      );
                      return DropdownMenuItem(
                        value: r,
                        child: Text(display),
                      );
                    },
                  ),
                  onChanged: _sending
                      ? null
                      : (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailCtrl,
              enabled: !_sending,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: trEn(
                  context,
                  'Açıklama (isteğe bağlı)',
                  'Description (optional)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(trEn(context, 'Gönder', 'Submit')),
            ),
          ],
        ),
      ),
    );
  }
}
