enum Direction {
  HORIZONTAL("HORIZONTAL"),
  VERTICAL("VERTICAL");

  final String direction;
  const Direction(this.direction);

  static Direction fromJson(String direction){
    return Direction.values.firstWhere((dir)=>dir.direction==direction);
  }
}
