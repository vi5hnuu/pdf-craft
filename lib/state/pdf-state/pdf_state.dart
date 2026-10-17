part of 'pdf_bloc.dart';

@Immutable("PdfState is replaced, never mutated — see the clone() calls in PdfBloc")
class PdfState extends Equatable with WithHttpState {

  PdfState._({
    Map<String,HttpState>? httpStates,
  }){
    this.httpStates.addAll(httpStates ?? {});
  }

  PdfState.initial()
      : this._(
          httpStates: const {},
        );

  PdfState copyWith({
    Map<String, HttpState>? httpStates,
  }) {
    return PdfState._(
      httpStates: httpStates ?? this.httpStates,
    );
  }

  @override
  List<Object?> get props => [httpStates];
}
