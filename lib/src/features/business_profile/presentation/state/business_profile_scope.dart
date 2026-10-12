import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/business_profile/presentation/state/business_profile_notifier.dart';

class BusinessProfileScope extends InheritedNotifier<BusinessProfileNotifier> {
  const BusinessProfileScope({
    required BusinessProfileNotifier notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static BusinessProfileNotifier of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BusinessProfileScope>();
    assert(scope != null, 'BusinessProfileScope not found in widget tree.');
    return scope!.notifier!;
  }
}
