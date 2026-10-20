import 'package:flutter/services.dart';
import 'src/online/bootstrap.dart';
import 'src/online/domain/online_models.dart';

Future<void> main() => runOnlineApp(
  appFlavor == 'customer' ? AppAudience.customer : AppAudience.business,
);
