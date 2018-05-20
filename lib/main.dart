import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/material.dart';

import 'select_photos.dart';

void main() => runApp(new RevSpaceApp());

List<RevImage> images = new List<RevImage>();
SelectPhotosState selectPhotosState;

class RevSpaceApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'RevSpace App',
      theme: new ThemeData(primarySwatch: Colors.lightGreen),
      home: new SelectPhotos(),
    );
  }
}

class RevImage {
  File file;
  int rotation;
  String description;

  RevImage(this.file, this.rotation);

  String toString() {
    return 'RevImage [${file.uri.toString()}; $rotation; $description]\n';
  }
}

class RevFileImage extends FileImage {
  RevImage _ri;
  BuildContext _context;

  RevFileImage(RevImage ri, BuildContext context) : super(ri.file) {
    _ri = ri;
    _context = context;
  }

  @override
  ImageStreamCompleter load(FileImage key) {
    return new MultiFrameImageStreamCompleter(
        codec: _loadAsync(key),
        scale: key.scale,
        informationCollector: (StringBuffer information) {
          information.writeln('Path: ${file?.path}');
        });
  }

  Future<ui.Codec> _loadAsync(FileImage key) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;


    ui.Codec imageCodec;
    try {
      imageCodec = await ui.instantiateImageCodec(bytes);
    } catch (e) {
      print('filename: ${file.path}');
      print('num_bytes: ${bytes.length}');
      selectPhotosState.setState(() {
        images.remove(_ri);
        Scaffold.of(_context).showSnackBar(new SnackBar(
          duration: new Duration(seconds: 4),
          content: new Text('That is not a valid photo.'),
        ));
      });
      // We need to clear the cache because if we don't and the user selects the same invalid photo twice
      // then the photo won't ever load using this method and we won't catch the exception.
      PaintingBinding.instance.imageCache.clear();
      // I need to provide some valid image data here so it can continue living before the ListView.builder removes the item.
      // If we don't we will just have the exception we are trying to handle again.
      // @formatter:off
      // stolen from https://github.com/shinnn/node-smallest-png/blob/master/index.js
      Uint8List dummy = new Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
      // @formatter:on      
      imageCodec = await ui.instantiateImageCodec(dummy);
    }
    return imageCodec;
  }
}

