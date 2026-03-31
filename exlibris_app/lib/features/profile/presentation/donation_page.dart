import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_components.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../data/payment_service.dart';

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final TextEditingController _amountController = TextEditingController(
    text: '5',
  );
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );
  int _selectedAmount = 5;
  String _currency = 'eur';
  bool _processing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount =
        int.tryParse(_amountController.text.trim()) ?? _selectedAmount;
    if (amount <= 0) {
      AppToast.warning(context, 'Entre un montant valide');
      return;
    }

    setState(() => _processing = true);
    try {
      final success = await PaymentService().makePayment(
        amount * 100,
        _currency,
      );
      if (!mounted) {
        return;
      }

      if (success) {
        await _showThankYouDialog();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
      } else {
        AppToast.warning(
          context,
          kIsWeb
              ? 'Le paiement n est pas encore disponible sur le web.'
              : 'Le paiement a echoue.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _showThankYouDialog() async {
    _confettiController.play();
    unawaited(_playCelebrationHaptics());
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0C2429),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIconBadge(
                        icon: Icons.favorite_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Merci beaucoup !',
                        style: AppTextStyles.heading2.copyWith(fontSize: 28),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ton don aide ExLibris a continuer de grandir.',
                        style: AppTextStyles.body.copyWith(height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.gradientEnd,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Continuer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.04,
                numberOfParticles: 24,
                gravity: 0.18,
                shouldLoop: false,
                colors: const [
                  AppColors.warning,
                  AppColors.accent,
                  AppColors.success,
                  Colors.white,
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _playCelebrationHaptics() async {
    final stopwatch = Stopwatch()..start();
    var useHeavy = true;

    while (stopwatch.elapsed < const Duration(seconds: 2)) {
      if (useHeavy) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
      useHeavy = !useHeavy;
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
  }

  void _applyPreset(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = '$amount';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Faire un don'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: AppDecorations.pageBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              AppHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        AppCountBadge(
                          label: 'Soutien',
                          color: AppColors.warning,
                        ),
                        Spacer(),
                        AppIconBadge(
                          icon: Icons.favorite_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aide ExLibris a continuer de grandir',
                      style: AppTextStyles.heading2.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ton don soutient le developpement de l app et les prochaines fonctionnalites.',
                      style: AppTextStyles.body.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(title: 'Pourquoi donner'),
                    SizedBox(height: 14),
                    _DonationReason(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Faire evoluer l application',
                      subtitle:
                          'Soutiens les prochaines ameliorations produit et UX.',
                    ),
                    SizedBox(height: 12),
                    _DonationReason(
                      icon: Icons.security_rounded,
                      title: 'Renforcer l experience',
                      subtitle:
                          'Aide a financer une app plus fluide et plus fiable.',
                    ),
                    SizedBox(height: 12),
                    _DonationReason(
                      icon: Icons.people_alt_rounded,
                      title: 'Soutenir la communaute',
                      subtitle:
                          'Encourage le developpement d une vraie plateforme de lecteurs.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(title: 'Choisir un montant'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [3, 5, 10, 20].map((amount) {
                        final selected = _selectedAmount == amount;
                        return _AmountChip(
                          amount: amount,
                          selected: selected,
                          onTap: () => _applyPreset(amount),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          setState(() => _selectedAmount = parsed);
                        }
                      },
                      decoration: AppDecorations.inputDecoration(
                        label: 'Montant libre',
                        prefixIcon: Icons.euro_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const AppSectionHeader(title: 'Devise'),
                    const SizedBox(height: 12),
                    _CurrencySelector(
                      selectedCurrency: _currency,
                      onChanged: (value) => setState(() => _currency = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppSurfaceCard(
                child: Row(
                  children: [
                    const AppIconBadge(
                      icon: Icons.lock_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Paiement securise via Stripe.',
                        style: AppTextStyles.bodyWhite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.gradientEnd,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: Text(_processing ? 'Traitement...' : 'Faire un don'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationReason extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DonationReason({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(icon: icon, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyWhite.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warning.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.warning.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          '$amount ${amount > 1 ? '€' : '€'}',
          style: TextStyle(
            color: selected ? AppColors.warning : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onChanged;

  const _CurrencySelector({
    required this.selectedCurrency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _CurrencyButton(
              label: 'EUR',
              selected: selectedCurrency == 'eur',
              onTap: () => onChanged('eur'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CurrencyButton(
              label: 'USD',
              selected: selectedCurrency == 'usd',
              onTap: () => onChanged('usd'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
