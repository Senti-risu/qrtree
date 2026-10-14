/// Converts internal service and database failures into short, actionable copy.
///
/// The original error can still be shown in a collapsed technical-details area
/// for administrators, but should not be the first message most users see.
String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  final value = raw.toLowerCase();

  if (value.contains('socket') ||
      value.contains('network') ||
      value.contains('connection') ||
      value.contains('failed host lookup') ||
      value.contains('timeout')) {
    return 'We could not connect to EcoTag. Check your internet connection and try again.';
  }
  if (value.contains('jwt') ||
      value.contains('session') ||
      value.contains('not authenticated')) {
    return 'Your session has expired. Sign in again to continue.';
  }
  if (value.contains('permission') ||
      value.contains('not authorized') ||
      value.contains('row-level security')) {
    return 'Your account does not have permission to complete this action.';
  }
  if (value.contains('incorrect username') ||
      value.contains('invalid login') ||
      value.contains('invalid credentials')) {
    return 'The username or password is incorrect.';
  }
  if (value.contains('inactive')) {
    return 'This account is inactive. Contact your EcoTag administrator.';
  }
  if (value.contains('too many unsuccessful') ||
      value.contains('temporarily locked') ||
      value.contains('locked until')) {
    return 'This account is temporarily locked after several unsuccessful sign-in attempts. Wait 15 minutes, then try again.';
  }
  if (value.contains('secure login is not enabled') ||
      value.contains('require_app_session')) {
    return 'Secure sign-in is not available yet. Contact your EcoTag administrator.';
  }
  if (value.contains('pgrst202') ||
      value.contains('pgrst204') ||
      value.contains('could not find the function') ||
      value.contains('schema cache') ||
      value.contains('archived_at') ||
      value.contains('lifecycle_status') ||
      value.contains('next_inspection_due_on')) {
    return 'EcoTag needs its latest database update before this feature can be used. Contact the system administrator.';
  }
  if (value.contains('no assigned role') ||
      value.contains('no assigned campus') ||
      value.contains('no assigned college')) {
    return 'This account is not fully configured. Contact your EcoTag administrator.';
  }

  return fallback;
}

String technicalErrorDetails(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
