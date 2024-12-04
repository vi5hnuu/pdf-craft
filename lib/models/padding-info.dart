class PaddingInfo {
  double top;
  double left;
  double bottom;
  double right;

  PaddingInfo({required this.top,required this.left,required this.bottom,required this.right});

  Map<String,dynamic> toJson(){
    return {
      "top":top,
      "left":left,
      "bottom":bottom,
      "right":right,
    };
  }
}
