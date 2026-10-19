// import 'dart:convert';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
// import 'package:http/http.dart' as http;

// import '../../components/constants.dart'; // your API base

// // const _WEB_CLIENT_ID = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

// class GoogleAuthButton extends StatefulWidget {
//   const GoogleAuthButton({super.key});

//   @override
//   State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
// }

// class _GoogleAuthButtonState extends State<GoogleAuthButton> {
//   late final GoogleSignIn _googleSignIn;
//   bool _checkingSilent = kIsWeb; // only do silent check on web
//   bool _busy = false;

//   @override
//   void initState() {
//     super.initState();

//     _googleSignIn = GoogleSignIn(
//       scopes: const ['email', 'profile'],
//       clientId: kIsWeb ? Constants.webClientId : null, // Web needs clientId
//       serverClientId:
//           kIsWeb
//               ? null
//               : Constants
//                   .webClientId, // Mobile needs serverClientId to get idToken
//     );

//     if (kIsWeb) _trySilentSignIn();
//   }

//   Future<void> _trySilentSignIn() async {
//     try {
//       final account = await _googleSignIn.signInSilently();
//       if (account != null) {
//         await _exchangeToken(account);
//         return;
//       }
//     } catch (_) {
//       // ignore; fall back to button
//     } finally {
//       if (mounted) setState(() => _checkingSilent = false);
//     }
//   }

//   Future<void> _onPressed() async {
//     if (_busy) return;
//     setState(() => _busy = true);

//     try {
//       // Try silent first (web recommendation), then popup
//       GoogleSignInAccount? account;
//       try {
//         account = await _googleSignIn.signInSilently();
//       } catch (_) {}
//       account ??=
//           await _googleSignIn.signIn(); // popup on web / native flow on mobile
//       if (account == null) return; // user canceled

//       await _exchangeToken(account);
//     } on PlatformException catch (e) {
//       // Common from web popup: popup_closed
//       if (e.code == 'popup_closed') {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Popup closed. Please try again.')),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(e.toString())));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _exchangeToken(GoogleSignInAccount account) async {
//     final auth = await account.authentication;
//     final idToken = auth.idToken;
//     if (idToken == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No Google ID token. Check clientId/serverClientId.'),
//         ),
//       );
//       return;
//     }

//     final res = await http.post(
//       Uri.parse('${Constants.socketUrl}/auth/google'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'idToken': idToken}),
//     );

//     if (!mounted) return;

//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Welcome, ${data["user"]["name"]}!')),
//       );
//       // TODO: save your own JWT from data['token'] and navigate
//     } else {
//       final err = jsonDecode(res.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(err['error'] ?? 'Google login failed')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (kIsWeb) {
//       // While we check silent sign-in, show a disabled button or spinner
//       if (_checkingSilent) {
//         return const SizedBox(
//           height: 40,
//           child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
//         );
//       }

//       // Render official GIS button (web)
//       return GoogleSignInPlatform.instance.renderButton(
//         configuration: const GSIButtonConfiguration(
//           type: GSIButtonType.standard,
//           theme: GSIButtonTheme.filledBlue,
//           size: GSIButtonSize.large,
//           text: GSIButtonText.continueWith,
//           shape: GSIButtonShape.pill,
//           logoAlignment: GSIButtonLogoAlignment.left,
//         ),
//         onPressed: _busy ? null : _onPressed,
//       );
//     }

//     // Mobile: your old OutlinedButton with Google logo
//     return OutlinedButton.icon(
//       onPressed: _busy ? null : _onPressed,
//       icon: Image.asset('assets/images/google_logo.png', height: 18),
//       label: Text(_busy ? 'Please wait…' : 'Continue with Google'),
//       style: OutlinedButton.styleFrom(
//         foregroundColor: Colors.white,
//         side: BorderSide(color: Colors.white.withOpacity(.35)),
//         shape: const StadiumBorder(),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         textStyle: const TextStyle(fontWeight: FontWeight.w700),
//         backgroundColor: Colors.white.withOpacity(.10),
//       ),
//     );
//   }
// }
