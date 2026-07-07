part of 'user_details_bloc.dart';

final class UserDetailsEvent extends Equatable {
  const UserDetailsEvent();

  @override
  List<Object> get props => [];
}

final class FetchUserDetails extends UserDetailsEvent {
  final String uid;
  const FetchUserDetails({required this.uid});
}


final class VoteUserVote extends UserDetailsEvent {
  final String fartId;
  final String voteType;

  const VoteUserVote({required this.fartId, required this.voteType});

  @override
  List<Object> get props => [fartId, voteType];
}
final class ReportUserFart extends UserDetailsEvent {
  final String fartId;
  final String reason;

  const ReportUserFart({required this.fartId, required this.reason});

  @override
  List<Object> get props => [fartId,reason];
}

