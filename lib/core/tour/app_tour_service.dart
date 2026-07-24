import 'package:shared_preferences/shared_preferences.dart';

/// Manages per-screen guided tour state using SharedPreferences.
///
/// The tour is **opt-in**. First-visit auto-start was removed: the assessment
/// tabs live inside an IndexedStack that builds every tab before it is visible,
/// and the Tests tab is rebuilt under a changing ValueKey, so "first visit"
/// fired at unpredictable moments — showing the tour repeatedly, and sometimes
/// against targets that weren't on screen yet.
///
/// Instead the user starts it deliberately ("Take a guided tour"), which clears
/// the seen-flags and arms auto-start for the rest of the session. Each screen
/// then shows its showcase once as the user reaches it, and nothing replays on
/// the next app launch.
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

  /// Armed only for the session in which the user explicitly starts the tour.
  /// Resets to false on every app launch, so tours never auto-start unasked.
  static bool _armed = false;

  static bool get isArmed => _armed;

  /// Entry point for the user-facing "Take a guided tour" action: clears the
  /// seen-flags and arms auto-start for this session.
  static Future<void> startGuidedTour() async {
    await resetAllTours();
    _armed = true;
  }

  /// Stops an in-progress tour without clearing what's already been seen.
  static void cancelGuidedTour() {
    _armed = false;
  }

  /// Returns true if this screen's showcase should run now. Always false unless
  /// the user has explicitly started the tour this session.
  static Future<bool> shouldShowTour(String screenKey) async {
    if (!_armed) return false;
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
