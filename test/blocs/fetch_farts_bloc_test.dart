import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the public farts feed. Focus is the enrichment path that
/// [FetchFartsBloc] runs on top of the raw `user_farts` query: resolving author
/// display names (deduplicated/batched) and the current user's vote/report
/// state, for both the first page and subsequent "load more" pages.
void main() {
  const currentUserId = 'user1';

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: currentUserId),
    );

    // Two authors — authorA owns two farts to exercise name deduplication.
    await firestore.collection('app_users').doc('authorA').set({'name': 'Alice'});
    await firestore.collection('app_users').doc('authorB').set({'name': 'Bob'});

    Future<void> seedFart(
      String id, {
      required String uid,
      required int upvotes,
      required String category,
      int reportCount = 0,
    }) {
      return firestore.collection('user_farts').doc(id).set({
        'uid': uid,
        'isPublic': true,
        'upvotes': upvotes,
        'downvotes': 0,
        'category': category,
        'title': id,
        'fileUrl': 'url/$id',
        'fileType': 'mp3',
        'duration': 3,
        'createdAt': 1,
        'updatedAt': 1,
        'region': 'Global',
        'commentCount': 0,
        'reportCount': reportCount,
      });
    }

    // upvotes drive the descending order: fart1(10) > fart2(5) > fart3(1).
    await seedFart('fart1', uid: 'authorA', upvotes: 10, category: 'Loud');
    await seedFart('fart2', uid: 'authorB', upvotes: 5, category: 'Wet', reportCount: 1);
    await seedFart('fart3', uid: 'authorA', upvotes: 1, category: 'Loud');

    // Current user's interactions: an upvote on fart1 and a report on fart2.
    await firestore
        .collection('user_farts')
        .doc('fart1')
        .collection('votes')
        .doc(currentUserId)
        .set({'type': 'upvote'});
    await firestore
        .collection('user_farts')
        .doc('fart2')
        .collection('reports')
        .doc(currentUserId)
        .set({'reason': 'Spam'});
  });

  FetchFartsBloc buildBloc() =>
      FetchFartsBloc(firestore: firestore, auth: auth);

  group('FetchTopFarts', () {
    blocTest<FetchFartsBloc, FetchFartsState>(
      'emits [Loading, Success] with author names, vote and report state',
      build: buildBloc,
      act: (bloc) => bloc.add(const FetchTopFarts()),
      expect: () => [isA<FetchFartsLoading>(), isA<FetchFartsSuccess>()],
      verify: (bloc) {
        final state = bloc.state as FetchFartsSuccess;

        // Ordered by upvotes descending.
        expect(state.farts.map((f) => f.id).toList(), ['fart1', 'fart2', 'fart3']);

        // Author names resolved; authorA (fart1 & fart3) resolves to the same name.
        expect(state.farts[0].userName, 'Alice');
        expect(state.farts[1].userName, 'Bob');
        expect(state.farts[2].userName, 'Alice');

        // Current user's vote/report state is layered on.
        expect(state.farts[0].userVote, 'upvote');
        expect(state.farts[1].userReported, isTrue);
        expect(state.farts[1].reportReason, 'Spam');
        expect(state.farts[2].userVote, isNull);
        expect(state.farts[2].userReported, isFalse);

        expect(state.hasMore, isFalse); // only 3 docs, below the page limit
      },
    );

    blocTest<FetchFartsBloc, FetchFartsState>(
      'applies the category filter',
      build: buildBloc,
      act: (bloc) => bloc.add(const FetchTopFarts(category: 'Loud')),
      verify: (bloc) {
        final state = bloc.state as FetchFartsSuccess;
        expect(state.farts.map((f) => f.id).toList(), ['fart1', 'fart3']);
      },
    );

    blocTest<FetchFartsBloc, FetchFartsState>(
      'emits failure when no user is signed in',
      build: () => FetchFartsBloc(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: false),
      ),
      act: (bloc) => bloc.add(const FetchTopFarts()),
      expect: () => [isA<FetchFartsLoading>(), isA<FetchFartsFailure>()],
    );
  });

  group('FetchMoreFarts', () {
    blocTest<FetchFartsBloc, FetchFartsState>(
      'enriches appended farts (pagination no longer drops author names)',
      build: buildBloc,
      seed: () => const FetchFartsSuccess(farts: [], hasMore: true),
      act: (bloc) async {
        // Use the top fart as the pagination cursor, then page after it.
        final firstPage = await firestore
            .collection('user_farts')
            .where('isPublic', isEqualTo: true)
            .orderBy('upvotes', descending: true)
            .limit(1)
            .get();
        bloc.add(FetchMoreFarts(firstPage.docs.last));
      },
      verify: (bloc) {
        final state = bloc.state as FetchFartsSuccess;
        // Everything after fart1, still enriched with author names.
        expect(state.farts.map((f) => f.id).toList(), ['fart2', 'fart3']);
        expect(state.farts[0].userName, 'Bob');
        expect(state.farts[1].userName, 'Alice');
      },
    );
  });
}
