import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mcq_test_app/core/constants/app_colors.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/core/widgets/app_gradient_background.dart';
import 'package:mcq_test_app/features/admin/screens/admin_dashboard.dart';
import 'package:mcq_test_app/features/auth/screens/change_password_screen.dart';
import 'package:mcq_test_app/features/auth/screens/login_screen.dart';
import 'package:mcq_test_app/features/teacher/screens/teacher_dashboard.dart';
import 'package:mcq_test_app/features/student/screens/student_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot entrance animation (logo, title, tagline, loader).
  late AnimationController _controller;
  // Endless ambient animation (particles, rotating ring, glow pulse, shimmer).
  late AnimationController _loop;

  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _ringFade;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _loaderFade;
  late Animation<double> _progress;

  late final List<_Particle> _particles;

  static const String _title = 'MCQ PRO';

  @override
  void initState() {
    super.initState();

    final rnd = math.Random(7);
    _particles = List.generate(26, (_) => _Particle.random(rnd));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _ringFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 1.0, curve: Curves.easeInOutCubic),
    );

    _controller.forward();
    _checkAuth();
  }

  void _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = SupabaseService().currentUser;

    if (user != null) {
      final profile = await SupabaseService().getUserProfile(user.id);
      if (mounted) {
        if (profile == null) {
          await SupabaseService().logout();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
          return;
        }

        if (!profile.isActive) {
          await SupabaseService().logout();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been deactivated. Please contact administrator.'),
                backgroundColor: AppColors.error,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
          return;
        }

        if (profile.isAdmin) {
          // If admin profile had must_change_password set, auto-clear it
          if (profile.mustChangePassword) {
            try {
              await SupabaseService().supabase.from('users').update({
                'must_change_password': false,
                'temporary_password': null,
              }).eq('id', user.id);
            } catch (_) {}
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        } else if (profile.isTeacher) {
          // First-time teacher login requires password change before dashboard access
          if (profile.mustChangePassword) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ChangePasswordScreen(user: profile)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => TeacherDashboard(user: profile)),
            );
          }
        } else if (profile.isStudent) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StudentDashboard(user: profile)),
          );
        } else {
          await SupabaseService().logout();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _loop.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- UI ----

  Widget _buildLogo() {
    const double size = 190;
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _loop]),
      builder: (context, _) {
        final t = _loop.value;
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft pulsing glow
              Opacity(
                opacity: _logoFade.value,
                child: Container(
                  width: 120 + 34 * pulse,
                  height: 120 + 34 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.22 + 0.14 * pulse),
                        blurRadius: 50 + 20 * pulse,
                        spreadRadius: 4 + 6 * pulse,
                      ),
                    ],
                  ),
                ),
              ),
              // Rotating gradient ring + orbiting dots
              Opacity(
                opacity: _ringFade.value,
                child: CustomPaint(
                  size: const Size(size, size),
                  painter: _RingPainter(progress: t),
                ),
              ),
              // Main logo disc
              Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x442F7CF6),
                          blurRadius: 30,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glossy highlight
                        Positioned(
                          top: 8,
                          left: 14,
                          child: Container(
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.38),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -2 * math.sin(t * 2 * math.pi * 2)),
                          child: const Icon(Icons.auto_stories,
                              size: 56, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _loop]),
      builder: (context, _) {
        final shimmer = _loop.value;
        final letters = <Widget>[];
        for (int i = 0; i < _title.length; i++) {
          final start = 0.35 + i * 0.045;
          final end = (start + 0.28).clamp(0.0, 1.0);
          final v = Curves.easeOutCubic.transform(
            ((_controller.value - start) / (end - start)).clamp(0.0, 1.0),
          );
          letters.add(
            Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - v)),
                child: Text(
                  _title[i],
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: _title[i] == ' ' ? 6 : 5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              AppColors.primary,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-2 + shimmer * 4, 0),
            end: Alignment(0 + shimmer * 4, 0),
            tileMode: TileMode.mirror,
          ).createShader(rect),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: letters,
          ),
        );
      },
    );
  }

  Widget _buildTagline(TextTheme textTheme) {
    return FadeTransition(
      opacity: _taglineFade,
      child: SlideTransition(
        position: _taglineSlide,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dividerLine(true),
            const SizedBox(width: 12),
            Text(
              'Smart Tests. Strong Outcomes.',
              style: textTheme.titleSmall?.copyWith(
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            _dividerLine(false),
          ],
        ),
      ),
    );
  }

  Widget _dividerLine(bool left) {
    return Container(
      width: 22,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: left
              ? [AppColors.primary.withOpacity(0.0), AppColors.primary]
              : [AppColors.secondary, AppColors.secondary.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildLoader(TextTheme textTheme) {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Container(
                      height: 5,
                      color: AppColors.primary.withOpacity(0.12),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progress.value.clamp(0.02, 1.0),
                      child: Container(
                        height: 5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Preparing your workspace…',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            // Ambient floating particles + soft blurred orbs
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => CustomPaint(
                  painter: _AmbientPainter(
                    t: _loop.value,
                    particles: _particles,
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 18),
                    _buildTitle(textTheme),
                    const SizedBox(height: 12),
                    _buildTagline(textTheme),
                  ],
                ),
              ),
            ),
            // Loader at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: _buildLoader(textTheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ painters ----

class _Particle {
  final double x, y, size, speed, phase;
  const _Particle(this.x, this.y, this.size, this.speed, this.phase);

  factory _Particle.random(math.Random r) => _Particle(
    r.nextDouble(),
    r.nextDouble(),
    1.5 + r.nextDouble() * 3.5,
    0.4 + r.nextDouble() * 0.9,
    r.nextDouble() * math.pi * 2,
  );
}

class _AmbientPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  _AmbientPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    // Large drifting color orbs
    void orb(Color c, double cx, double cy, double r, double phase) {
      final dx = math.sin(t * 2 * math.pi + phase) * 24;
      final dy = math.cos(t * 2 * math.pi + phase) * 24;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c.withOpacity(0.20), c.withOpacity(0.0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * cx + dx, size.height * cy + dy),
            radius: r,
          ),
        );
      canvas.drawCircle(
        Offset(size.width * cx + dx, size.height * cy + dy),
        r,
        paint,
      );
    }

    orb(AppColors.primary, 0.15, 0.18, size.width * 0.55, 0);
    orb(AppColors.secondary, 0.90, 0.82, size.width * 0.60, 2.2);

    // Rising particles
    for (final p in particles) {
      final prog = (p.y - t * p.speed) % 1.0;
      final yy = (prog < 0 ? prog + 1 : prog) * size.height;
      final xx = p.x * size.width +
          math.sin(t * 2 * math.pi * 2 + p.phase) * 10;
      final fade = math.sin((yy / size.height) * math.pi).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.lerp(AppColors.primary, AppColors.secondary, p.x)!
            .withOpacity(0.35 * fade);
      canvas.drawCircle(Offset(xx, yy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.t != t;
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final angle = progress * 2 * math.pi;

    // Faint static track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.primary.withOpacity(0.15),
    );

    // Rotating sweep arc
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      rect,
      0,
      math.pi * 1.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 1.35,
          colors: [
            AppColors.primary.withOpacity(0.0),
            AppColors.primary,
            AppColors.secondary,
          ],
        ).createShader(rect),
    );
    canvas.restore();

    // Orbiting dots (opposite direction)
    for (int i = 0; i < 3; i++) {
      final a = -angle * 1.4 + i * (2 * math.pi / 3);
      final pos = center + Offset(math.cos(a), math.sin(a)) * (radius - 14);
      canvas.drawCircle(
        pos,
        3.2 - i * 0.6,
        Paint()
          ..color = (i.isEven ? AppColors.primary : AppColors.secondary)
              .withOpacity(0.85),
      );
    }

    // Leading bright dot on the sweep arc
    final headAngle = angle + math.pi * 1.35;
    final head = center + Offset(math.cos(headAngle), math.sin(headAngle)) * radius;
    canvas.drawCircle(
      head,
      6,
      Paint()
        ..color = AppColors.secondary.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(head, 3.4, Paint()..color = AppColors.secondary);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}