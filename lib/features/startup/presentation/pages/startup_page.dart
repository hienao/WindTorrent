import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/startup_trace.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  static const bool _lightweightFirstFrame = true;
  static const Duration _heavyEffectsDelay = Duration(milliseconds: 450);
  late final AnimationController _controller;
  Timer? _navigationTimer;
  Timer? _effectsTimer;
  bool _didLogFirstBuild = false;
  bool _showHeavyEffects = false;

  @override
  void initState() {
    super.initState();
    StartupTrace.mark('startup_page_init_state');
    StartupTrace.mark('startup_page_lightweight=$_lightweightFirstFrame');

    if (_lightweightFirstFrame) {
      _effectsTimer = Timer(_heavyEffectsDelay, () {
        if (!mounted) return;
        setState(() {
          _showHeavyEffects = true;
        });
        StartupTrace.mark('startup_page_heavy_effects_enabled');
      });
    } else {
      _showHeavyEffects = true;
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _navigationTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        StartupTrace.mark('startup_page_navigate_home');
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _effectsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_didLogFirstBuild) {
      _didLogFirstBuild = true;
      StartupTrace.mark('startup_page_first_build');
    }
    final theme = Theme.of(context);
    final tokens = theme.extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_controller.value);
                      final scale = 0.96 + (t * 0.06);
                      final dy = (0.5 - t) * 10;

                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: tokens.raisedSurface,
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(
                          color: tokens.highlightColor.withValues(
                            alpha: tokens.isDark ? 0.08 : 0.65,
                          ),
                        ),
                        boxShadow: !_showHeavyEffects
                            ? const []
                            : [
                                BoxShadow(
                                  color: tokens.primaryAccent.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(
                        'assets/branding/app_icon_master.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'WindTorrent',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Torrent Manager',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        color: tokens.primaryAccent,
                        backgroundColor: tokens.recessedSurface,
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
