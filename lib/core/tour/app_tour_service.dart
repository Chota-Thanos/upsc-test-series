import 'package:shared_preferences/shared_preferences.dart';

/// Manages per-screen guided tour state using SharedPreferences.
///
/// Each screen has its own seen-flag so tours auto-start on first visit
/// and never replay unless explicitly reset.
class AppTourService {
  static const String listScreenKey = 'tour_seen_tests_list_v1';
  static const String createScreenKey = 'tour_seen_test_create_v1';
  static const String attemptScreenKey = 'tour_seen_attempt_v1';
  static const String resultScreenKey = 'tour_seen_result_v1';
  static const String dashboardScreenKey = 'tour_seen_dashboard_v1';

  /// Step 0 of the real Create Test tour: choosing GS / CSAT / Mains on the
  /// TestsHubScreen tab bar.
  static const String contentTypeSelectKey = 'tour_seen_content_type_select_v1';

  /// Steps 1+ run on SelfTestBuilderTab, tracked independently per content
  /// type so switching from GS to Mains (say) still shows a first-visit tour
  /// tailored to Mains, even if GS was already seen.
  static const List<String> builderContentTypes = ['gk', 'aptitude', 'mains'];
  static String builderScreenKeyFor(String contentType) => 'tour_seen_builder_${contentType}_v1';

  /// Returns true if the tour for this screen hasn't been shown yet.
  static Future<bool> shouldShowTour(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(screenKey) ?? false);
  }

  /// Marks this screen's tour as seen so it doesn't auto-start again.
  static Future<void> markTourSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(screenKey, true);
  }

  /// Resets all tours — useful for a "Replay Tour" settings option.
  static Future<void> resetAllTours() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      listScreenKey,
      createScreenKey,
      attemptScreenKey,
      resultScreenKey,
      dashboardScreenKey,
      contentTypeSelectKey,
      ...builderContentTypes.map(builderScreenKeyFor),
    ]) {
      await prefs.remove(key);
    }
  }
}
