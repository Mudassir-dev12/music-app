import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart' as config;
import '../../session/session_controller.dart';
import '../../theme/tokens.dart';

/// Shows an Apple Music-styled dialog to edit and persist the API base URL.
Future<void> showServerUrlDialog(BuildContext context, WidgetRef ref) async {
  final tokens = Theme.of(context).extension<MelodiaTokens>() ?? MelodiaTokens.dark;
  final controller = TextEditingController(text: config.apiUrl);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MelodiaTokens.radiusSheet),
            ),
            title: Text(
              'Backend Server URL',
              style: MelodiaTokens.title3.copyWith(color: tokens.text),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the address of your Melodia backend:',
                    style: MelodiaTokens.subhead.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MelodiaTokens.spacingMd),
                  TextField(
                    controller: controller,
                    style: MelodiaTokens.body.copyWith(color: tokens.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: tokens.surface2,
                      hintText: 'http://192.168.0.104:8000',
                      hintStyle: MelodiaTokens.body.copyWith(
                        color: tokens.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MelodiaTokens.spacingMd,
                        vertical: MelodiaTokens.spacingSm,
                      ),
                    ),
                  ),
                  const SizedBox(height: MelodiaTokens.spacingMd),
                  Text(
                    'Quick Presets:',
                    style: MelodiaTokens.caption.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: MelodiaTokens.spacingSm),
                  Wrap(
                    spacing: MelodiaTokens.spacingSm,
                    runSpacing: MelodiaTokens.spacingSm,
                    children: [
                      ActionChip(
                        label: Text(
                          'Phone Wi-Fi (192.168.0.104)',
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.text,
                          ),
                        ),
                        backgroundColor: tokens.surface2,
                        side: BorderSide.none,
                        onPressed: () {
                          setState(() {
                            controller.text = 'http://192.168.0.104:8000';
                          });
                        },
                      ),
                      ActionChip(
                        label: Text(
                          'Emulator (10.0.2.2)',
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.text,
                          ),
                        ),
                        backgroundColor: tokens.surface2,
                        side: BorderSide.none,
                        onPressed: () {
                          setState(() {
                            controller.text = 'http://10.0.2.2:8000';
                          });
                        },
                      ),
                      ActionChip(
                        label: Text(
                          'Localhost (127.0.0.1)',
                          style: MelodiaTokens.footnote.copyWith(
                            color: tokens.text,
                          ),
                        ),
                        backgroundColor: tokens.surface2,
                        side: BorderSide.none,
                        onPressed: () {
                          setState(() {
                            controller.text = 'http://127.0.0.1:8000';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancel',
                  style: MelodiaTokens.subhead.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accent,
                ),
                onPressed: () {
                  final newUrl = controller.text.trim();
                  if (newUrl.isNotEmpty) {
                    ref.read(sessionProvider.notifier).updateServerUrl(newUrl);
                  }
                  Navigator.of(dialogCtx).pop();
                },
                child: Text(
                  'Save & Connect',
                  style: MelodiaTokens.subhead.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
