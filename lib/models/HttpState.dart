class HttpState {
  final bool loading;
  final double? progress; // null = indeterminate, 0.0–1.0 = determinate upload progress
  final String? error;
  final bool? done;
  final Map<String, Object>? extras;

  const HttpState({this.loading = false, this.progress, this.error, this.done, this.extras});

  const HttpState.loading({this.progress})
      : loading = true,
        error = null,
        done = null,
        extras = null;

  const HttpState.done({Map<String, Object>? extras})
      : this(done: true, extras: extras);

  const HttpState.error({required String? error})
      : this(loading: false, error: error);
}
