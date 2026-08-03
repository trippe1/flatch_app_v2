/// Tokenizer for community search.
///
/// The same rules run server-side (see `functions/index.js`) when building the
/// `searchTokens` index on each fart, so a query tokenized here matches the
/// tokens stored there. Keep the two in sync.
library;

/// Lowercase, split on anything that isn't a letter or digit, drop 1-char
/// noise, de-duplicate. "Uncle Bob's LOUDEST!!" → [uncle, bob, loudest]
List<String> tokenizeSearch(String input) {
  final seen = <String>{};
  for (final raw in input.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
    if (raw.length < 2) continue;
    seen.add(raw);
  }
  return seen.toList();
}
