class HttpState{
  final bool loading;
  final String? error;
  final bool? done;
  final Map<String,String>? extras;

  const HttpState({this.loading=false,this.error,this.done,this.extras});
  const HttpState.loading():this(loading: true);
  const HttpState.done({Map<String,String>? extras}):this(done: true,extras: extras);
  const HttpState.error({required String? error}):this(loading: false,error: error);
}