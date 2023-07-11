import 'package:flutter/material.dart';
import '../utils/math.dart';

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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final renderBox = context.findRenderObject() as RenderBox;
              final local = renderBox.globalToLocal(details.globalPosition);
              _width += details.delta.dx * sign(local.dx - _width * 0.5) * 2;
              _height += details.delta.dy * sign(local.dy - _height * 0.5) * 2;

              // Limit min
              if (_width < 50) {
                _width = 50;
              }
              if (_height < 50) {
                _height = 50;
              }

              // Limit max
              if (_width > maxWidth) {
                _width = maxWidth;
              }
              if (_height > maxHeight) {
                _height = maxHeight;
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
      },
    );
  }
}
