
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  Map payload = {};
  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)!.settings.arguments;

    //for background
    if (data is RemoteMessage) {
      payload = data.data;
    }

    //? For Foreground
    // if (data is NotificationResponse) {
    //   payload = jsonDecode(data.payload!);
    // }

    return Scaffold(
      // appBar: const RRHeader(),
      body: Text(payload.toString()),
    );
  }
}
