import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_config/app_config.dart';
import '../../../../core/theme/app_theme.dart';

class HomeBannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;

  const HomeBannerCarousel({super.key, required this.banners});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _controller = PageController(viewportFraction: .94);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _page = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.banners.length,
        onPageChanged: (value) => _page = value,
        itemBuilder: (context, index) {
          final banner = widget.banners[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Semantics(
              button: banner.actionUrl != null,
              label: banner.title ?? 'إعلان',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: banner.actionUrl == null
                    ? null
                    : () => launchUrl(
                        banner.actionUrl!,
                        mode: LaunchMode.externalApplication,
                      ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.indigo.withValues(alpha: .08),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          banner.imageUrl.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                        if (banner.title?.trim().isNotEmpty == true)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: Colors.black.withValues(alpha: .48),
                              child: Text(
                                banner.title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
