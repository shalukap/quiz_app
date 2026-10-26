import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/grades.dart';
import '../config/premium_config.dart';
import '../services/firestore_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_ui.dart';

/// QuizMaster Premium paywall. Route args: `{'grade': int?}`.
/// Pops with `true` after a successful purchase.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _subs = SubscriptionService.instance;

  bool _argsLoaded = false;
  int? _grade;
  List<int> _grades = [];
  Offering? _offering;
  bool _loadingOffering = false;
  PremiumPlan _plan = PremiumPlan.yearly;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _grade = args?['grade'] as int?;
    _loadGrades();
    if (_grade != null) _loadOffering(_grade!);
  }

  Future<void> _loadGrades() async {
    try {
      // Opened for an EB exam: offer the EB exams instead of school grades
      final grades = _grade != null && Grades.isEbExam(_grade!)
          ? Grades.ebExams
          : await FirestoreService().getActiveGrades();
      if (!mounted) return;
      setState(() {
        _grades = grades;
        if (_grade == null && grades.isNotEmpty) {
          _grade = grades.first;
          _loadOffering(_grade!);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadOffering(int grade) async {
    setState(() => _loadingOffering = true);
    final offering = await _subs.offeringForGrade(grade);
    if (!mounted || grade != _grade) return;
    setState(() {
      _offering = offering;
      _loadingOffering = false;
    });
  }

  void _selectGrade(int grade) {
    if (grade == _grade) return;
    setState(() {
      _grade = grade;
      _offering = null;
    });
    _loadOffering(grade);
  }

  bool get _isOneTime => _selectedPlan.isOneTime;

  List<PremiumPlan> get _plans => PremiumConfig.plansFor(_grade);

  /// The chosen subscription plan, or the only plan a one-time grade offers.
  PremiumPlan get _selectedPlan => _plans.contains(_plan) ? _plan : _plans.first;

  String _priceFor(PremiumPlan plan) =>
      SubscriptionService.packageFor(_offering, plan)?.storeProduct.priceString ??
      PremiumConfig.fallbackPrices[plan]!;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _subscribe() async {
    final package = SubscriptionService.packageFor(_offering, _selectedPlan);
    if (package == null) {
      _snack("This plan isn't available right now. Please try again later.");
      return;
    }
    setState(() => _purchasing = true);
    final (outcome, error) = await _subs.purchase(package);
    if (!mounted) return;
    setState(() => _purchasing = false);
    switch (outcome) {
      case PurchaseOutcome.success:
        _snack('Welcome to ${PremiumConfig.displayName}! 🎉');
        Navigator.pop(context, true);
      case PurchaseOutcome.pending:
        _snack('Payment pending. Premium unlocks as soon as ${PremiumConfig.storeName} confirms it.');
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.error:
        _snack('Purchase failed${error != null ? ': $error' : '. Please try again.'}');
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final restored = await _subs.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    _snack(restored ? 'Premium restored 🎉' : 'No active purchase found for this store account.');
  }

  Future<void> _manage() async {
    final url = _subs.managementUrl ?? PremiumConfig.manageSubscriptionsUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        context,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: GlassBackButton(icon: Icons.close_rounded),
        ),
      ),
      body: AuroraBackground(
        premium: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _subs,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FadeSlideIn(child: _Hero()),
                  const SizedBox(height: 24),
                  if (_grades.length > 1) ...[
                    FadeSlideIn(index: 1, child: _buildGradePicker()),
                    const SizedBox(height: 20),
                  ],
                  if (_grade != null && _subs.hasGrade(_grade!))
                    FadeSlideIn(index: 2, child: _buildActiveCard(_grade!))
                  else ...[
                    FadeSlideIn(index: 2, child: _buildBenefits()),
                    const SizedBox(height: 20),
                    if (!_subs.isAvailable) ...[
                      _buildUnavailableNotice(),
                      const SizedBox(height: 20),
                    ],
                    FadeSlideIn(index: 3, child: _buildPlans()),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: _grade == null
                          ? 'Subscribe'
                          : _isOneTime
                              ? 'Buy · ${_priceFor(_selectedPlan)} one-time'
                              : 'Subscribe · ${_priceFor(_selectedPlan)} ${_selectedPlan.period}',
                      icon: Icons.workspace_premium_rounded,
                      gradient: AppGradients.gold,
                      foregroundColor: PremiumStyle.onGold,
                      glowColor: PremiumStyle.gold,
                      loading: _purchasing,
                      onPressed: _subs.isAvailable && _grade != null && !_loadingOffering ? _subscribe : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_subs.isAvailable)
                    Center(
                      child: TextButton(
                        onPressed: _restoring ? null : _restore,
                        child: Text(
                          _restoring ? 'Restoring…' : 'Restore purchases',
                          style: AppText.style(weight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _isOneTime
                        ? 'One-time payment per exam. No subscription and nothing to cancel.'
                        : 'Prices are per grade. Subscriptions renew automatically until cancelled. '
                            '${PremiumConfig.cancelInstructions}',
                    textAlign: TextAlign.center,
                    style: AppText.style(size: 11.5, color: AppColors.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legalLink('Terms of Use', PremiumConfig.termsUrl),
                      Text('·', style: AppText.style(size: 11.5, color: AppColors.textMuted)),
                      _legalLink('Privacy Policy', PremiumConfig.privacyPolicyUrl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legalLink(String label, String url) {
    return TextButton(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: AppText.style(size: 11.5, weight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildGradePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_grade != null && Grades.isEbExam(_grade!) ? 'CHOOSE YOUR EXAM' : 'CHOOSE YOUR GRADE', style: AppText.overline(color: PremiumStyle.goldLight)),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _grades.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = _grades[i];
              final selected = g == _grade;
              final owned = _subs.hasGrade(g);
              return Pressable(
                onTap: () => _selectGrade(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? AppGradients.gold : null,
                    color: selected ? null : AppColors.glassFill,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: selected ? Colors.transparent : AppColors.glassStroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (owned) ...[
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: selected ? PremiumStyle.onGold : PremiumStyle.gold),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        Grades.label(g),
                        style: AppText.style(
                          size: 13,
                          weight: FontWeight.w700,
                          color: selected ? PremiumStyle.onGold : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBenefits() {
    final grade = _grade == null ? 'your grade' : Grades.label(_grade!);
    final items = [
      (Icons.lock_open_rounded, 'Every question set', 'All subjects and sets in $grade'),
      (Icons.block_rounded, 'No ads', 'No banners, pop-ups or video ads anywhere'),
      (Icons.auto_awesome_rounded, 'Premium look', 'Exclusive gold theme across the app'),
      (Icons.devices_rounded, 'Follows your account', 'Sign in on any Android phone'),
    ];
    return GlassCard(
      blur: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          for (final (icon, title, subtitle) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PremiumStyle.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: PremiumStyle.goldLight),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.style(size: 14.5, weight: FontWeight.w700)),
                        Text(subtitle, style: AppText.style(size: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlans() {
    return Column(
      children: [
        for (final plan in _plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanCard(
              plan: plan,
              price: _priceFor(plan),
              selected: plan == _selectedPlan,
              loading: _loadingOffering,
              onTap: () => setState(() => _plan = plan),
            ),
          ),
      ],
    );
  }

  Widget _buildUnavailableNotice() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: PremiumStyle.goldLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Purchases are not available on this device right now. Please try again later.',
              style: AppText.body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(int grade) {
    final ent = _subs.entitlementFor(grade);
    final expiry = ent?.expirationDate != null ? DateTime.tryParse(ent!.expirationDate!) : null;
    final dateText = expiry == null ? null : DateFormat('d MMM yyyy').format(expiry.toLocal());
    return GlassCard(
      accent: PremiumStyle.gold,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const PremiumBadge(label: 'Active'),
          const SizedBox(height: 14),
          Text("You're Premium for ${Grades.label(grade)}", textAlign: TextAlign.center, style: AppText.title()),
          if (ent != null && expiry == null) ...[
            const SizedBox(height: 6),
            Text('Lifetime access', style: AppText.body()),
          ],
          if (dateText != null) ...[
            const SizedBox(height: 6),
            Text(
              ent!.willRenew ? 'Renews on $dateText' : 'Ends on $dateText',
              style: AppText.body(),
            ),
          ],
          if (expiry != null) ...[
            const SizedBox(height: 18),
            GlassButton(label: 'Manage subscription', icon: Icons.open_in_new_rounded, onPressed: _manage, height: 50),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.gold,
            boxShadow: [
              BoxShadow(color: PremiumStyle.gold.withValues(alpha: 0.55), blurRadius: 48, spreadRadius: -2),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded, size: 46, color: PremiumStyle.onGold),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) => AppGradients.gold.createShader(bounds),
          child: Text(
            PremiumConfig.displayName,
            textAlign: TextAlign.center,
            style: AppText.style(size: 28, weight: FontWeight.w800, spacing: -0.8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock every question set and learn without ads',
          textAlign: TextAlign.center,
          style: AppText.body(),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final String price;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumStyle.gold.withValues(alpha: 0.22),
                    PremiumStyle.gold.withValues(alpha: 0.06),
                  ],
                )
              : AppGradients.glass(),
          border: Border.all(
            color: selected ? PremiumStyle.gold : AppColors.glassStroke,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: PremiumStyle.gold.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: -6)]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppGradients.gold : null,
                border: Border.all(color: selected ? Colors.transparent : AppColors.glassStroke, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 14, color: PremiumStyle.onGold) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Text(plan.label, style: AppText.style(size: 15.5, weight: FontWeight.w700)),
                  if (plan.saving != null) ...[
                    const SizedBox(width: 8),
                    PremiumBadge(label: plan.saving!, compact: true),
                  ],
                ],
              ),
            ),
            loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price, style: AppText.style(size: 15.5, weight: FontWeight.w800)),
                      Text(plan.period, style: AppText.style(size: 11, color: AppColors.textMuted)),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
