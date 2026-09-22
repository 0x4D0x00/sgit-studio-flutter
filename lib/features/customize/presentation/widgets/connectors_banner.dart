import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

// Connectors 顶部推荐轮播：三张卡片每 4 秒自动切换一次，可手动左右翻页。
class _PromoSlide {
  const _PromoSlide({
    required this.title,
    required this.subtitle,
    required this.icons,
  });

  final String title;
  final String subtitle;
  final List<_PromoIconSpec> icons;
}

class _PromoIconSpec {
  const _PromoIconSpec(this.icon, this.color);

  final IconData icon;
  final Color color;
}

const _kSlides = [
  _PromoSlide(
    title: 'Claude for design',
    subtitle: 'Sketch, diagram, and iterate with your creative tools.',
    icons: [
      _PromoIconSpec(Icons.circle, Color(0xFF6366F1)),
      _PromoIconSpec(Icons.crop_square, Colors.black),
      _PromoIconSpec(Icons.change_history, Color(0xFFEF4444)),
      _PromoIconSpec(Icons.star, Color(0xFFF59E0B)),
      _PromoIconSpec(Icons.palette, Color(0xFF8B5CF6)),
      _PromoIconSpec(Icons.more_horiz, Colors.grey),
    ],
  ),
  _PromoSlide(
    title: 'Claude for productivity',
    subtitle: 'Plan, draft, and organize work across your everyday tools.',
    icons: [
      _PromoIconSpec(Icons.calendar_today, Color(0xFF4285F4)),
      _PromoIconSpec(Icons.mail, Color(0xFFEA4335)),
      _PromoIconSpec(Icons.description, Colors.black),
      _PromoIconSpec(Icons.folder, Color(0xFF4285F4)),
      _PromoIconSpec(Icons.forum, Color(0xFF611f69)),
      _PromoIconSpec(Icons.more_horiz, Colors.grey),
    ],
  ),
  _PromoSlide(
    title: 'Claude for engineering',
    subtitle: 'Ship faster by connecting Claude to your dev stack.',
    icons: [
      _PromoIconSpec(Icons.code, Color(0xFF181717)),
      _PromoIconSpec(Icons.bug_report, Color(0xFFF24E1E)),
      _PromoIconSpec(Icons.storage, Color(0xFF00C4CC)),
      _PromoIconSpec(Icons.terminal, Colors.black),
      _PromoIconSpec(Icons.cloud, Color(0xFF4285F4)),
      _PromoIconSpec(Icons.more_horiz, Colors.grey),
    ],
  ),
];

/// Connectors 顶部推荐轮播：三张卡片每 3 秒自动切换一次，可手动左右翻页。
class ConnectorsPromoBanner extends StatefulWidget {
  const ConnectorsPromoBanner({
    super.key,
    required this.skin,
    required this.onExplore,
  });

  final AppSkin skin;
  final VoidCallback onExplore;

  @override
  State<ConnectorsPromoBanner> createState() => _ConnectorsPromoBannerState();
}

class _ConnectorsPromoBannerState extends State<ConnectorsPromoBanner> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _goToPage((_currentPage + 1) % _kSlides.length);
    });
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _handleManualNav(int delta) {
    _goToPage((_currentPage + delta) % _kSlides.length);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1a3a3a), const Color(0xFF0d2626)]
              : [const Color(0xFFD5E8E5), const Color(0xFFEEF5F4)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _kSlides.length,
              itemBuilder: (context, index) {
                return _PromoSlideView(
                  slide: _kSlides[index],
                  isDark: isDark,
                  onExplore: widget.onExplore,
                  onPrev: () => _handleManualNav(-1),
                  onNext: () => _handleManualNav(1),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDotIndicators(isDark),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildDotIndicators(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kSlides.length, (index) {
        final isActive = index == _currentPage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 24 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white30 : Colors.black26),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _PromoSlideView extends StatelessWidget {
  const _PromoSlideView({
    required this.slide,
    required this.isDark,
    required this.onExplore,
    required this.onPrev,
    required this.onNext,
  });

  final _PromoSlide slide;
  final bool isDark;
  final VoidCallback onExplore;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        children: [
          Text(
            'CURATED BY ANTHROPIC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF7FA39D) : const Color(0xFF5B7A76),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFFB8C9C6) : const Color(0xFF4A5E5B),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildIconCarousel(),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onExplore,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: isDark ? const Color(0xFF4A5E5B) : const Color(0xFF8FA9A5),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text(
              'Explore',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconCarousel() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -12,
          child: IconButton(
            icon: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: onPrev,
          ),
        ),
        Positioned(
          right: -12,
          child: IconButton(
            icon: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: onNext,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final spec in slide.icons) ...[
              _PromoIcon(icon: spec.icon, color: spec.color, isDark: isDark),
              if (spec != slide.icons.last) const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ],
    );
  }
}

class _PromoIcon extends StatelessWidget {
  const _PromoIcon({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}
