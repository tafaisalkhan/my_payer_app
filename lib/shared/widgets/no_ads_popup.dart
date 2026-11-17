import 'package:flutter/material.dart';
import 'package:mynamaz_scheduler/core/services/support_service.dart';

/// Rotating support/engagement popup shown on Home when ads are inactive.
class NoAdsPopup extends StatefulWidget {
  final int step;
  final bool isStreakReward;
  final bool isAdFreePurchased;

  const NoAdsPopup({
    super.key,
    required this.step,
    this.isStreakReward = false,
    this.isAdFreePurchased = false,
  });

  static Future<void> show(
    BuildContext context, {
    required int step,
    bool isStreakReward = false,
    bool isAdFreePurchased = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoAdsPopup(
        step: step % 3,
        isStreakReward: isStreakReward,
        isAdFreePurchased: isAdFreePurchased,
      ),
    );
  }

  @override
  State<NoAdsPopup> createState() => _NoAdsPopupState();
}

class _NoAdsPopupState extends State<NoAdsPopup> {
  int _selectedStars = 5;
  bool _isBusy = false;

  String get _headline {
    if (widget.isAdFreePurchased) {
      return 'Thank You for Your Support!';
    }
    if (widget.isStreakReward) {
      return '3-Day Streak! No Ads Today';
    }
    return 'No Ads Today';
  }

  String get _subtitle {
    if (widget.isAdFreePurchased) {
      return 'You enjoy an ad-free experience! Would you like to support the app further?';
    }
    if (widget.isStreakReward) {
      return 'You opened the app 3 days in a row — enjoy an ad-free day on us!';
    }
    return 'Ads are paused right now. Enjoy a peaceful, distraction-free experience.';
  }

  String get _dismissText =>
      widget.isAdFreePurchased ? 'Close' : 'Maybe Later';

  Future<void> _handleRateSubmit() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      if (_selectedStars >= 4) {
        await SupportService.instance.requestInAppReview();
        if (mounted) Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! We will keep improving.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await SupportService.instance.shareApp();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleCoffee() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await SupportService.instance.buyCoffee();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.step % 3;

    final IconData icon;
    final Color accent;
    final String actionTitle;
    final String actionBody;
    final String primaryLabel;

    switch (step) {
      case 0:
        icon = Icons.star_rounded;
        accent = Colors.amber.shade700;
        actionTitle = 'Enjoying MyNamaz Scheduler?';
        actionBody = 'Tap a star rating to let us know how your experience has been.';
        primaryLabel = 'Rate on Google Play';
        break;
      case 1:
        icon = Icons.share_rounded;
        accent = theme.colorScheme.primary;
        actionTitle = 'Share With Friends & Family';
        actionBody = 'Help others stay consistent with their daily prayers.';
        primaryLabel = 'Share App';
        break;
      default:
        icon = Icons.coffee_rounded;
        accent = Colors.brown.shade600;
        actionTitle = 'Buy Developer a Coffee';
        actionBody =
            'Support ongoing updates and new Islamic features for ${SupportService.instance.coffeePrice}.';
        primaryLabel = 'Buy Coffee (${SupportService.instance.coffeePrice})';
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  actionTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  actionBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (step == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _isBusy
                            ? null
                            : () => setState(() => _selectedStars = star),
                        icon: Icon(
                          star <= _selectedStars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber.shade700,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: Text(_dismissText),
        ),
        FilledButton(
          onPressed: _isBusy
              ? null
              : () {
                  if (step == 0) {
                    _handleRateSubmit();
                  } else if (step == 1) {
                    _handleShare();
                  } else {
                    _handleCoffee();
                  }
                },
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(primaryLabel),
        ),
      ],
    );
  }
}
