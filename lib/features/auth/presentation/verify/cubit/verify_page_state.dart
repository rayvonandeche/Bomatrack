part of 'verify_page_cubit.dart';

final class VerifyPageState extends Equatable {
  final bool isVerified;
  final String? error;
  const VerifyPageState({this.isVerified = false, this.error});

  VerifyPageState copyWith({bool? isVerified, String? error}) {
    return VerifyPageState(isVerified: isVerified ?? this.isVerified, error: error ?? this.error);
  }

  @override
  List<Object> get props => [isVerified];
}

