import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationService {
  //assign this key to topmost widget
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  NotificationService._();

  static get messengerKey => _scaffoldMessengerKey;

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSnackbar({required String text, MaterialColor color = Colors.red, bool showCloseIcon = true,Duration? duration}){
      final snackbar = SnackBar(
      content: Text(text),
      elevation: 5,
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: showCloseIcon,
      duration: duration ?? const Duration(seconds: 2),
    );
    return _scaffoldMessengerKey.currentState?.showSnackBar(snackbar);
  }

}
