import 'dart:io' as IO;
import 'dart:async' as Async;
import 'dart:typed_data' as TypedData;
import 'dart:ui' as UI show instantiateImageCodec, Codec;

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
  IO.File file;
  int rotation = 0;
  String description;
  double progress = 0.0;
  List<int> resizedJpeg;

  RevImage(this.file);

  String toString() {
    return 'RevImage ['
        '${file.path
        .split('/')
        .last}; '
        '${rotation % 4 * 90}°; '
        '$description]';
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

  Async.Future<UI.Codec> _loadAsync(FileImage key) async {
    assert(key == this);

    final TypedData.Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;


    UI.Codec imageCodec;
    try {
      imageCodec = await UI.instantiateImageCodec(bytes);
    } catch (e) {
      debugPrint('Not a valid photo. File: ${file.path} Size: ${bytes.length}');
      selectPhotosState.setState(() {
        images.remove(_ri);
        Scaffold.of(_context).showSnackBar(new SnackBar(
          duration: new Duration(seconds: 4),
          content: new Text('${file.path
              .split('/')
              .last} is not a valid photo.'),
        ));
      });
      // We need to clear the cache because if we don't and the user selects the same invalid photo twice
      // then the photo won't ever load using this method and we won't catch the exception.
      PaintingBinding.instance.imageCache.clear();
      // I need to provide some valid image data here so it can continue living before the ListView.builder removes the item.
      // If we don't we will just have the exception we are trying to handle again.
      // @formatter:off
      // stolen from https://github.com/shinnn/node-smallest-png/blob/master/index.js
      TypedData.Uint8List dummy = new TypedData.Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
      // @formatter:on      
      imageCodec = await UI.instantiateImageCodec(dummy);
    }
    return imageCodec;
  }
}

