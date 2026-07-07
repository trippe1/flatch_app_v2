import 'dart:math';
import 'package:flatch/common/enums/comment_filter_enum.dart';
import 'package:flatch/common/enums/fart_filters.dart';
import 'package:flatch/common/models/comment_model.dart';
import 'package:flatch/common/models/fart_model.dart';

class AppLogics {
  AppLogics._();
  static final AppLogics instance = AppLogics._();

  List<FartModel> applyFilter(List<FartModel> farts, FartFilter filter) {
    final sorted = List<FartModel>.from(farts);

    switch (filter) {
      case FartFilter.all:
      case FartFilter.sortBy:
        break;

      case FartFilter.popular:
        sorted.sort((a, b) {
          double aScore =
              (a.upvotes - a.downvotes).toDouble() +
              (0.3 * a.commentCount) -
              (2.0 * a.reportCount);
          double bScore =
              (b.upvotes - b.downvotes).toDouble() +
              (0.3 * b.commentCount) -
              (2.0 * b.reportCount);
          return bScore.compareTo(aScore);
        });
        break;

      case FartFilter.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;

      case FartFilter.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case FartFilter.flagged:
        return sorted.where((fart) => (fart.reportCount ?? 0) > 0).toList();

      case FartFilter.controversial:
        sorted.sort((a, b) {
          double controversy(FartModel x) {
            if (x.upvotes <= 0 || x.downvotes <= 0) return 0;
            double ratio =
                min(x.upvotes, x.downvotes) / max(x.upvotes, x.downvotes);
            return (x.upvotes + x.downvotes) * ratio +
                (0.2 * x.commentCount) -
                (1.5 * x.reportCount);
          }

          final aScore = controversy(a);
          final bScore = controversy(b);
          int cmp = bScore.compareTo(aScore);
          if (cmp != 0) return cmp;
          int aVotes = a.upvotes + a.downvotes;
          int bVotes = b.upvotes + b.downvotes;
          return bVotes.compareTo(aVotes);
        });
        break;
    }

    return sorted;
  }
  List<CommentModel> applyCommentFilter(
    List<CommentModel> comments,
    CommentFilter filter,
  ) {
    final sorted = List<CommentModel>.from(comments);

    switch (filter) {
      case CommentFilter.all:
      case CommentFilter.sortBy:
        break;

      case CommentFilter.popular:
        sorted.sort((a, b) {
          double aScore =
              (a.upvotes - a.downvotes).toDouble() +
              (0.3 * a.replies.length) -
              (2.0 * (a.reportCount));
          double bScore =
              (b.upvotes - b.downvotes).toDouble() +
              (0.3 * b.replies.length) -
              (2.0 * (b.reportCount));
          return bScore.compareTo(aScore);
        });
        break;

      case CommentFilter.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;

      case CommentFilter.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
        

      case CommentFilter.controversial:
        sorted.sort((a, b) {
          double controversy(CommentModel x) {
            if (x.upvotes <= 0 || x.downvotes <= 0) return 0;
            double ratio =
                min(x.upvotes, x.downvotes) / max(x.upvotes, x.downvotes);
            return (x.upvotes + x.downvotes) * ratio +
                (0.2 * x.replies.length) -
                (1.5 * (x.reportCount));
          }

          final aScore = controversy(a);
          final bScore = controversy(b);
          int cmp = bScore.compareTo(aScore);
          if (cmp != 0) return cmp;
          int aVotes = a.upvotes + a.downvotes;
          int bVotes = b.upvotes + b.downvotes;
          return bVotes.compareTo(aVotes);
        });
        break;
    }

    return sorted;
  }

  String getFilterDisplayName(FartFilter filter) {
    switch (filter) {
      case FartFilter.sortBy:
        return "SORT BY";
      case FartFilter.all:
        return "ALL";
      case FartFilter.popular:
        return "POPULAR";
      case FartFilter.newest:
        return "NEWEST";
      case FartFilter.oldest:
        return "OLDEST";
      case FartFilter.controversial:
        return "CONTRO";
        case FartFilter.flagged:
        return "FLAGGED";
    }

  }
  String getCommentFilterDisplayName(CommentFilter filter) {
    switch (filter) {
      case CommentFilter.sortBy:
        return "SORT BY";
      case CommentFilter.all:
        return "ALL";
      case CommentFilter.popular:
        return "POPULAR";
      case CommentFilter.newest:
        return "NEWEST";
      case CommentFilter.oldest:
        return "OLDEST";
      case CommentFilter.controversial:
        return "CONTRO";
    }
  }
}
