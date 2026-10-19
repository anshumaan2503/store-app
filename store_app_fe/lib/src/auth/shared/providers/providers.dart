import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../../components/constants.dart';
// import 'dart:io';

// class MyHttpOverrides extends HttpOverrides { /// SSl CERTIFICATE BYPASS
//   @override
//   HttpClient createHttpClient(SecurityContext? context) {
//     return super.createHttpClient(context)
//       ..badCertificateCallback =
//           (X509Certificate cert, String host, int port) =>
//               true; // Accept all certificates
//   }
// }

// final httpClientProvider = Provider<http.Client>((ref) {
//   HttpOverrides.global = MyHttpOverrides();
//   return http.Client();
// });

final httpClientProvider = Provider((ref) => http.Client());

final fcmTokenProvider = FutureProvider<String?>((ref) async {
  if (!kIsWeb) {
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      // Save or use the refreshed token
    });

    return await FirebaseMessaging.instance.getToken();
  } else {
    return await FirebaseMessaging.instance
        .getToken(vapidKey: Constants.fcmVapidKey);
  }
});

final loggerProvider = Provider(
  (ref) => Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      colors: true,
      printEmojis: true,
    ),
  ),
);

// final dateTimeFormatterProvider = Provider<DateFormat>((ref) {
//   return DateFormat.MMMEd().add_jm();
// });

final dateTimeFormatterProviderNew = Provider((ref) => DateTimeFormatterNew());

class DateTimeFormatterNew {
  String format(DateTime dateTime) {
    return DateFormat('hh:mm a  dd-MM-yyyy').format(dateTime);
  }
}

final dateFormatterProviderNew = Provider((ref) => DateFormatterNew());

class DateFormatterNew {
  String format(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy').format(dateTime);
  }
}

final dateTimeFormatterProvider = Provider((ref) => DateFormatter());

class DateFormatter {
  String format(DateTime dateTime) {
    // Format the DateTime to show only the date (e.g., "yyyy-MM-dd")
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}

final monthDateFormatterProvider = Provider<DateFormat>((ref) {
  return DateFormat.MMMd();
});

final dateFormatterProvider = Provider<DateFormat>((ref) {
  return DateFormat.yMMMEd();
});

final timeFormatterProvider = Provider<DateFormat>((ref) {
  return DateFormat("hh : mm : ss a");
});
