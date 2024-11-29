class HttpState{
  final bool loading;
  final String? error;

  const HttpState({this.loading=false,this.error});
  const HttpState.loading():this(loading: true);
  const HttpState.error({required String? error}):this(loading: false,error: error);
}