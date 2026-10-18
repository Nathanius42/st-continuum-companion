import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

void main() {
  // League Gothic and Pathway Gothic are under the Open Font License, which
  // travels with them.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'League Gothic',
      'Pathway Gothic',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const DexApp());
}
