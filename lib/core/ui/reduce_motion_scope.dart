import 'package:material_ui/material_ui.dart';

/// Folds iOS «Reduce Motion» (`AccessibilityFeatures.reduceMotion`) into
/// `MediaQuery.disableAnimations` for everything below, so every widget that
/// asks `Motion.reduced` or `MediaQuery.disableAnimationsOf` respects it.
/// Flutter sets `disableAnimations` only for Android's «Remove animations».
///
/// It rebuilds when the platform's accessibility features change, and it
/// always wraps [child] in the same `MediaQuery`, so a toggle never remounts
/// the app. `AnimationController` scaling (`SemanticsBinding`) is untouched.
/// [новое имя — согласовать]
class ReduceMotionScope extends StatefulWidget {
  const ReduceMotionScope({super.key, required this.child});

  final Widget child;

  @override
  State<ReduceMotionScope> createState() => _ReduceMotionScopeState();
}

class _ReduceMotionScopeState extends State<ReduceMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = View.of(context)
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: widget.child,
    );
  }
}
