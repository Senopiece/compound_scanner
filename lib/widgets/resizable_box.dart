import 'package:flutter/material.dart';

class ResizableBox extends StatefulWidget {
  const ResizableBox({Key? key}) : super(key: key);

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

          // Limit width and height
          if (_width < 100) {
            _width = 100;
          }
          if (_height < 100) {
            _height = 100;
          }
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
