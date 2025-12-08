import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/widgets/pages/onboarding_page.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'entry_choice_screen.dart';

class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_Slide> slides = [
    _Slide(
      icon: Image.asset('assets/images/bitcoin.png'),
      title: 'Your Bitcoin, Your Control',
      subtitle: 'No problems with banks or government',
      description:
          'Keep your Bitcoin safe. Nobody fit block your money or freeze your account.',
    ),
    _Slide(
      icon: Image.asset('assets/images/lightening.png'),
      title: 'Send Money Fast',
      subtitle: 'Lightning fast payments',
      description:
          'Send Bitcoin to anybody for free or small fee. e reach in seconds, not days.',
    ),
    _Slide(
      icon: Image.asset('assets/images/handshake.png'),
      title: 'Trade P2P, No Middleman',
      subtitle: 'Buy and sell Bitcoin directly',
      description:
          'Connect with other Nigerians to buy and sell Bitcoin. Your money, your rules.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: slides.length,
              itemBuilder: (_, index) {
                final slide = slides[index];
                return OnboardingPage(
                  icon: SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(child: slide.icon),
                  ),
                  title: slide.title,
                  subtitle: slide.subtitle,
                  description: slide.description,
                );
              },
            ),

            // Skip button - top right
            Positioned(
              top: 16,
              right: 24,
              child: TextButton(
                onPressed:
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EntryChoiceScreen(),
                      ),
                    ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Bottom section with indicator and button
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: Color(0xFF2A2A3E),
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == 2) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EntryChoiceScreen(),
                            ),
                          );
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF0C0C1A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == 2 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
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
}

class _Slide {
  final Widget icon;
  final String title, subtitle, description;
  _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}
