import 'package:logger/logger.dart';

/// App-wide shared logger. Use instead of `print` so log output is leveled and
/// automatically suppressed in release builds.
final Logger appLogger = Logger();
