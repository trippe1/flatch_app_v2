/// Client-side offensive-language check for community upload titles. Mirrors the
/// server-side list in `functions/index.js` (moderateNewFart) so the app can
/// warn the user immediately; the Cloud Function remains the source of truth /
/// enforcement. Keep the two lists roughly in sync.
class ProfanityFilter {
  static const List<String> _words = [
    'fuck', 'fuckn', 'fuckin', 'fucking', 'fucked', 'fucks', 'fucker',
    'fuckers', 'fuckwad', 'fuckface', 'motherfucker', 'motherfuckers', 'stfu',
    'wtf', 'shit', 'shite', 'shitty', 'shithead', 'shithole', 'bullshit',
    'dipshit', 'bitch', 'bitches', 'bitchy', 'cunt', 'cunts', 'asshole',
    'assholes', 'dumbass', 'jackass', 'bastard', 'bastards', 'dick', 'dicks',
    'dickhead', 'pussy', 'pussies', 'cock', 'cocks', 'slut', 'sluts', 'whore',
    'whores', 'douche', 'douchebag', 'wank', 'wanker', 'bollocks', 'prick',
    'pricks', 'twat', 'jerkoff', 'cum', 'cumshot', 'boner',
    // slurs / hate
    'fag', 'fags', 'faggot', 'faggots', 'nigger', 'niggers', 'nigga', 'niggas',
    'retard', 'retarded', 'spic', 'chink', 'kike', 'coon', 'dyke', 'tranny',
    'gook', 'wetback', 'beaner',
  ];

  // Words safe to also match after stripping ALL separators ("f u c k"); only
  // words that never appear inside innocent words (avoids the Scunthorpe trap).
  static const Set<String> _collapse = {
    'fuck',
    'fucking',
    'fucked',
    'motherfucker',
    'bitch',
    'asshole',
    'faggot',
    'nigger',
    'nigga',
    'bastard',
    'dickhead',
    'bullshit',
    'dumbass',
  };

  static const Set<String> _slurs = {
    'fag',
    'fags',
    'faggot',
    'faggots',
    'nigger',
    'niggers',
    'nigga',
    'niggas',
    'retard',
    'retarded',
    'spic',
    'chink',
    'kike',
    'coon',
    'dyke',
    'tranny',
    'gook',
    'wetback',
    'beaner',
  };

  static String _deLeet(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[@4]'), 'a')
        .replaceAll(RegExp(r'[!1|]'), 'i')
        .replaceAll('3', 'e')
        .replaceAll('0', 'o')
        .replaceAll(RegExp(r'[$5]'), 's')
        .replaceAll('7', 't');
  }

  /// Returns the offending word if [text] contains profanity/a slur, else null.
  static String? find(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final deleet = _deLeet(text);
    for (final w in _words) {
      if (RegExp('\\b$w\\b').hasMatch(deleet)) return w;
    }
    final collapsed = deleet.replaceAll(RegExp(r'[^a-z]'), '');
    for (final w in _collapse) {
      if (collapsed.contains(w)) return w;
    }
    return null;
  }

  /// True if [text] is clean (no profanity/slur).
  static bool isClean(String? text) => find(text) == null;

  /// Whether the matched word is a slur/hate term (vs general profanity).
  static bool isSlur(String word) => _slurs.contains(word);
}
