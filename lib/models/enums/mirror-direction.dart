enum MirrorDirection {
  horizontal,
  vertical;

  String get wire => this == MirrorDirection.horizontal ? 'HORIZONTAL' : 'VERTICAL';
  String get label => this == MirrorDirection.horizontal ? 'Horizontal' : 'Vertical';
}
