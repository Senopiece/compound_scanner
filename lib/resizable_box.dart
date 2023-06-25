import 'package:flutter/material.dart';

// TODO: fix negative box
class ResizableBox extends StatefulWidget {
  const ResizableBox({super.key});

  @override
  State<ResizableBox> createState() => ResizableBoxState();
}

class ResizableBoxState extends State<ResizableBox> {
  double _width = 200;
  double _height = 200;

  Size getSize() => Size(_width, _height);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _width += details.delta.dx;
          _height += details.delta.dy;
        });
      },
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
        ),
      ),
    );
  }
}
