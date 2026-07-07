import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  // --- Keys ---
  static const String _firstVisitKey = 'first_visit';
  static const String _domainsKey = 'domains';
  static const String _aiUsageKey = 'agree_to_ai_usage';
  static const String _recentSearchesKey = 'recent_searches';
  static const String _recentVisited = 'recent_visited';

  // --- Constants ---
  static const int _maxRecentSearches = 10;
  static const int _maxRecentVisited = 4;

  Future<void> saveClickedGig(String gigId) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentVisited) ?? [];

    recent.remove(gigId);
    recent.insert(0, gigId);

    if (recent.length > _maxRecentVisited) {
      recent.removeRange(_maxRecentVisited, recent.length);
    }

    await prefs.setStringList(_recentVisited, recent);
  }

  Future<List<String>> getRecentVisitedGigs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentVisited) ?? [];
  }

  Future<void> removeVisitedGig(String gigId) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentVisited) ?? [];
    recent.remove(gigId);
    await prefs.setStringList(_recentVisited, recent);
  }

  Future<void> clearVisitedGigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentVisited);
  }

  Future<void> saveFirstViewDetails() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(_firstVisitKey, true);
  }

  Future<bool> getFirstVisitDetails() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(_firstVisitKey) ?? false;
  }

  Future<void> deleteFirstVisitDetails() async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(_firstVisitKey);
  }

  Future<void> addOrRemoveDomainPrefreferences(String domain) async {
    final pref = await SharedPreferences.getInstance();
    List<String> added = pref.getStringList(_domainsKey) ?? [];

    if (added.contains(domain) && added.length == 1) return;

    if (!added.contains(domain)) {
      added.add(domain);
    } else {
      added.remove(domain);
    }

    await pref.setStringList(_domainsKey, added);
  }

  Future<List<String>> getDomains() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getStringList(_domainsKey) ?? [];
  }

  Future<bool> agreeToAIUsage() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(_aiUsageKey) ?? false;
  }

  Future<void> saveAgreeToAIUsage() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(_aiUsageKey, true);
  }

  Future<void> initFirstViewThings() async {
    final getDetails = await getFirstVisitDetails();
    if (!getDetails) {
      final pref = await SharedPreferences.getInstance();
      await pref.setStringList(_domainsKey, [
        "🎓 Student Visa",
        "💼 Work Visa",
        "🧳 Visit Visa",
        "🏢 Business Visa",
      ]);
    }
  }

  Future<void> saveSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];

    searches.remove(query);
    searches.insert(0, query);

    if (searches.length > _maxRecentSearches) {
      searches = searches.sublist(0, _maxRecentSearches);
    }

    await prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<void> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];
    searches.remove(query);
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}
