import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/onboarding_slide.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  var _index = 0;

  static const _slides = <OnboardingSlide>[
    OnboardingSlide(
      icon: Icons.restaurant_menu_outlined,
      title: 'Sajha Kharcha',
      description:
          'Split expenses. Stay friends. Built for meals, trips, rent, gifts, and Saving Circle in Nepal.',
      note: 'English | नेपाली',
    ),
    OnboardingSlide(
      icon: Icons.document_scanner_outlined,
      title: 'Scan. Auto-detect. Split.',
      description:
          'Scan a receipt and let Sajha Kharcha detect items, totals, VAT, and service charge before you review.',
    ),
    OnboardingSlide(
      icon: Icons.diversity_3_outlined,
      title: 'For every shared moment',
      description:
          'Use one social wallet layer for expenses, trips, gifts, and transparent Saving Circle commitments.',
      note: 'Scan. Split. Settle. Together.',
    ),
  ];

  bool get _last => _index == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  _LogoMark(color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sajha Kharcha',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _complete,
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _index = value),
                children: _slides,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: i == _index ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _index
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _last ? _complete : _next,
                      child: Text(_last ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _complete() async {
    await AuthScope.of(context).completeIntro();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/auth');
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'S',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}
