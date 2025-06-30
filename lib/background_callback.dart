import 'package:flutter/material.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  print('proceso repetitivo');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
