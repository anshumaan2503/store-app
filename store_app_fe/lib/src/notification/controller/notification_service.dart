// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';

// class PushNotification {
//   static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   static Future<void> localNotiInit() async {
//     // Request permission for Android 13+ using permission_handler
//     await _requestNotificationPermission();

//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     final DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings();

//     final InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );

//     // Initialize plugin with tap handlers
//     await _flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: onNotificationTap,
//       onDidReceiveBackgroundNotificationResponse: onNotificationTap,
//     );
//   }

//   // ✅ Proper way to request notification permission on Android 13+
//   static Future<void> _requestNotificationPermission() async {
//     final status = await Permission.notification.status;
//     if (!status.isGranted) {
//       await Permission.notification.request();
//     }
//   }

//   // Called when user taps a notification (foreground or background)
//   static void onNotificationTap(NotificationResponse notificationResponse) async {
//     final String? payload = notificationResponse.payload;
//     if (payload != null) {
//       print("Notification tapped with payload: $payload");
//       // TODO: Navigate or handle tap
//     }
//   }
// }
