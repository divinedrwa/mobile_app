/// Human-readable screen labels for Firebase `screen_view` and custom analytics.
abstract class AnalyticsScreenNames {
  AnalyticsScreenNames._();

  static const screenClass = 'gatepass_app';

  static String labelForPath(String rawPath) {
    final path = rawPath.split('?').first.trim();
    if (path.isEmpty) return 'Unknown';

    const exact = {
      '/': 'Splash',
      '/login': 'Login',
      '/society-select': 'Society select',
      '/legal-consent': 'Legal consent',
      '/resident': 'Resident home',
      '/resident/pre-approve-visitor': 'Pre-approve visitor',
      '/resident/my-pre-approved-visitors': 'My pre-approved visitors',
      '/resident/sos': 'SOS',
      '/resident/sos/active': 'Active SOS',
      '/resident/maintenance': 'Maintenance hub',
      '/resident/maintenance/history': 'Maintenance history',
      '/resident/maintenance/dues': 'My dues',
      '/resident/complaints': 'Submit complaint',
      '/resident/my-complaints': 'My complaints',
      '/resident/amenities': 'Amenities',
      '/resident/amenity-bookings': 'Amenity bookings',
      '/resident/visitor-hub': 'Visitor hub',
      '/resident/visitor-history': 'Visitor history',
      '/resident/visitor-approval-requests': 'Visitor approvals',
      '/resident/notices': 'Notices',
      '/resident/parcels': 'Parcels',
      '/resident/profile': 'Profile',
      '/resident/admin/app-analytics': 'Admin app analytics',
      '/resident/tab/home': 'Home tab',
      '/resident/tab/community': 'Community tab',
      '/resident/tab/admin': 'Admin tab',
      '/resident/tab/profile': 'Profile tab',
      '/resident/tab/community/notices': 'Community · Notices',
      '/resident/tab/community/polls': 'Community · Polls',
      '/resident/tab/community/events': 'Community · Events',
      '/resident/tab/community/docs': 'Community · Documents',
      '/resident/admin-only': 'Admin-only mode',
      '/guard/dashboard': 'Guard dashboard',
      '/guard/tab/dashboard': 'Guard · Dashboard tab',
      '/guard/tab/active': 'Guard · Active tab',
      '/guard/tab/logs': 'Guard · Logs tab',
      '/guard/tab/profile': 'Guard · Profile tab',
    };

    if (exact.containsKey(path)) return exact[path]!;

    if (path.startsWith('/resident/maintenance/cycle/')) return 'Maintenance cycle';
    if (path.startsWith('/admin/')) {
      final slug = path.replaceFirst('/admin/', '').replaceAll('-', ' ');
      return 'Admin · ${slug.isEmpty ? 'home' : slug}';
    }
    if (path.startsWith('/guard/')) {
      final slug = path.replaceFirst('/guard/', '').replaceAll('-', ' ');
      return 'Guard · ${slug.isEmpty ? 'home' : slug}';
    }

    return path
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          if (w.isEmpty) return '';
          return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
        })
        .join(' ');
  }
}
