import 'package:flutter/widgets.dart';

/// App-wide "animations on/off" setting, combined with the OS reduced-motion flag.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    return (scope?.enabled ?? true) && !MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool updateShouldNotify(MotionScope old) => old.enabled != enabled;
}
