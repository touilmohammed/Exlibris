import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../data/auth_repository.dart';

/// A reusable dialog for email confirmation code entry.
Future<bool> showEmailConfirmationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String email,
}) async {
  final codeController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: AppDecorations.sectionCard.copyWith(
                color: AppColors.backgroundLight,
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        size: 40,
                        color: AppColors.gradientEnd,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Vérifie tes mails',
                      style: AppTextStyles.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Un code a été envoyé à :\n$email',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: codeController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: AppDecorations.inputDecoration(
                        label: 'Code de confirmation',
                      ).copyWith(
                        hintText: '000000',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer le code';
                        }
                        if (value.length < 4) {
                          return 'Code trop court';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => loading = true);
                                try {
                                  await ref.read(authRepositoryProvider).confirmEmail(
                                        email: email,
                                        code: codeController.text.trim(),
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppToast.error(
                                      context,
                                      'Code invalide ou expiré',
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => loading = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.gradientEnd,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gradientEnd,
                                ),
                              )
                            : const Text('Valider'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () async {
                              setState(() => loading = true);
                              try {
                                await ref
                                    .read(authRepositoryProvider)
                                    .resendConfirmation(email: email);
                                if (context.mounted) {
                                  AppToast.success(context, 'Nouveau code envoyé !');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.error(context, 'Erreur lors de l’envoi');
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => loading = false);
                                }
                              }
                            },
                      child: const Text(
                        'Renvoyer le code',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Annuler',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return result ?? false;
}
