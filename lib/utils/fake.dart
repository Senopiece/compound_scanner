import 'package:flutter/material.dart';

Stream<String> fakeStream(String str) async* {
  var accum = "";
  for (var ch in str.characters) {
    accum += ch;
    yield accum;
    await Future.delayed(const Duration(milliseconds: 30));
  }
}
