class ColorInfo {
  final int r;
  final int g;
  final int b;
  final int? a;

  ColorInfo({required this.r,required this.g,required this.b,required this.a});

  Map<String,dynamic> toJson(){
    return {
      "r":r,
      "g":g,
      "b":b,
      "a":a,
    };
  }
}
