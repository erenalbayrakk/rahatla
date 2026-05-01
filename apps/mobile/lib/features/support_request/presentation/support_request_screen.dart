import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/mood/mood_catalog.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../../shared/widgets/soft_header.dart';
import '../data/support_request_repository.dart';

/// API `SupportCategory` değerleri (Prisma enum) — etiketler [MoodCatalog] ile hizalanır.
const _kCategoryValues = <String>[
  'vent',
  'need_someone_to_listen',
  'calm_chat',
  'motivation',
  'not_feeling_alone',
];

/// API `CommunicationPreference`.
const _kCommunicationValues = <String>[
  'text_chat',
  'voice_note',
  'live_voice',
];

String _communicationLabel(BuildContext context, String value) {
  return switch (value) {
    'text_chat' => trEn(context, 'Yazılı sohbet', 'Text chat'),
    'voice_note' => trEn(context, 'Ses notu', 'Voice note'),
    'live_voice' => trEn(context, 'Canlı ses', 'Live voice'),
    _ => value,
  };
}

class SupportRequestScreen extends ConsumerStatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  ConsumerState<SupportRequestScreen> createState() =>
      _SupportRequestScreenState();
}

class _SupportRequestScreenState extends ConsumerState<SupportRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  String _category = _kCategoryValues.first;
  String _communication = _kCommunicationValues.first;
  bool _submitting = false;

  static const _languageCode = 'tr';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SoftHeader(
              title: trEn(context, 'Destek isteği', 'Support request'),
              subtitle: trEn(
                context,
                'Nasıl hissediyorsun ve nasıl konuşmak istersin? Seçtikten sonra uygun dinleyenleri görebilirsin.',
                'How do you feel and how would you like to talk? After you choose, you can see suitable listeners.',
              ),
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 8),
            Text(
              trEn(context, 'Kategori', 'Category'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCategoryValues.map((value) {
                final selected = _category == value;
                return ChoiceChip(
                  label: Text(MoodCatalog.labelLocalized(context, value)),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              trEn(context, 'İletişim tercihi', 'Communication'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCommunicationValues.map((value) {
                final selected = _communication == value;
                return ChoiceChip(
                  label: Text(_communicationLabel(context, value)),
                  selected: selected,
                  onSelected: (_) => setState(() => _communication = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              trEn(context, 'Not (isteğe bağlı)', 'Note (optional)'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: trEn(
                  context,
                  'İstersen kısaca yaz…',
                  'Add a short note (optional)…',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            CalmCTAButton(
              label: trEn(
                context,
                'Uygun dinleyenleri listele',
                'List suitable listeners',
              ),
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(supportRequestRepositoryProvider);
      final created = await repo.create(
        category: _category,
        languageCode: _languageCode,
        communicationPreference: _communication,
        note: _noteController.text,
      );
      if (!mounted) return;
      context.push(RoutePaths.browseListeners, extra: created.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
