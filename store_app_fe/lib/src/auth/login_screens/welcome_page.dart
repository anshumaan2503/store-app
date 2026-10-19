import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:store_app/src/auth/login_screens/screen.dart';
// import '../constants.dart'; // optional; colors below are inline
// import '../screens/screen.dart'; // keep your imports as needed

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Palette that matches the illustration (beige bg + mint/peach accents)
    const beige = Color(0xFFFBF4EA);
    const mint = Color(0xFF79C7B5);
    const ink = Color(0xFF2F3A3A);

    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 20,
                    vertical: isWide ? 40 : 24,
                  ),
                  child:
                      isWide
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Illustration
                              Expanded(
                                flex: 6,
                                child: Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: AspectRatio(
                                    aspectRatio:
                                        2000 / 1768, // keep image ratio
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Image.asset(
                                        'assets/images/team_illustration.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                              // Text + buttons
                              Expanded(
                                flex: 5,
                                child: _WelcomeCopyAndActions(
                                  mint: mint,
                                  ink: ink,
                                ),
                              ),
                            ],
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AspectRatio(
                                  aspectRatio: 2000 / 1768,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Image.asset(
                                      'assets/images/team_illustration.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _WelcomeCopyAndActions(mint: mint, ink: ink),
                            ],
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeCopyAndActions extends StatelessWidget {
  final Color mint;
  final Color ink;
  const _WelcomeCopyAndActions({required this.mint, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Enterprise team\ncollaboration.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: ink,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Bring together your files, tools, projects and people. '
            'Including a new mobile and desktop application.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: ink.withValues(alpha: .8),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Button row
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                  child: const Text('Register'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: mint, width: 1.5),
                    backgroundColor: Colors.grey[850],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Sign In'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
