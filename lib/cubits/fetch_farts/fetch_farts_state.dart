part of 'fetch_farts_cubit.dart';

class FetchFartsCubitState extends Equatable {
  final String? selectedCategory;
  final List<FartModel> farts;

  const FetchFartsCubitState({this.selectedCategory, this.farts = const []});

  FetchFartsCubitState copyWith({
    String? selectedCategory,
    List<FartModel>? farts,
  }) {
    return FetchFartsCubitState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      farts: farts ?? this.farts,
    );
  }

  @override
  List<Object?> get props => [selectedCategory, farts];
}
