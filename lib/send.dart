import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'main.dart';

class RevSend {
  static Scaffold getScaffold(List<RevImage> images) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Send to RevSpace Wiki'),
      ),
      body: new Text(images.toString()),
    );
  }
}
