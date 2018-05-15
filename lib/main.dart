import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(new MyApp());

List<RevImage> images = new List<RevImage>();

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return new MyAppState();
  }
}

class RevImage {
  File file;
  int rotation;

  RevImage(this.file, this.rotation);
}

class RevFileImage extends FileImage {
  RevImage _ri;

  RevFileImage(RevImage ri) : super(ri.file) {
    _ri = ri;
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
      images.remove(_ri);
      // @formatter:off
      // stolen from https://github.com/shinnn/node-smallest-png/blob/master/index.js
      Uint8List dummy = new Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        10,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        13,
        10,
        45,
        180,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130
      ]);
      // @formatter:on
      imageCodec = await ui.instantiateImageCodec(dummy);
    }
    return imageCodec;
  }
}

class MyAppState extends State<MyApp> {
  final myController = new TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    myController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Basic List';

    return new MaterialApp(
      title: title,
      theme: new ThemeData(primarySwatch: Colors.lightGreen),
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text(title),
          actions: [
            new IconButton(
              onPressed: () => _onImageButtonPressed(ImageSource.gallery),
              tooltip: 'Add photo from gallery',
              icon: new Icon(Icons.add_photo_alternate),
            ),
            new IconButton(
              onPressed: () => _onImageButtonPressed(ImageSource.camera),
              tooltip: 'Add photo from camera',
              icon: new Icon(Icons.add_a_photo),
            ),
            new IconButton(
              onPressed: () => _onSendButtonPressed,
              tooltip: 'Send to RevSpace wiki',
              color: (images.length > 0) ? Colors.black : Colors.grey,
              icon: new Icon(Icons.send),
            ),
          ],
        ),
        body: new ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              return new Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: new Row(children: [
                  new RotatedBox(
                    quarterTurns: images[index].rotation,
                    child: new FadeInImage(
                        placeholder: new AssetImage('assets/loading.gif'),
                        image: new RevFileImage(images[index]),
                        width: 144.0,
                        height: 144.0,
                        fit: BoxFit.cover),
                  ),
                  new Flexible(
                    child: new Column(children: [
                      new TextField(
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          labelText: 'Description',
                        ),
                        maxLines: 3,
                      ),
                      new Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          new IconButton(
                            iconSize: 32.0,
                            onPressed: () {
                              setState(() {
                                images[index].rotation++;
                              });
                            },
                            icon: new Icon(Icons.rotate_right, color: Theme.of(context).primaryColor),
                          ),
                          new IconButton(
                            iconSize: 32.0,
                            onPressed: () {
                              setState(() {
                                images[index].rotation--;
                              });
                            },
                            icon: new Icon(Icons.rotate_left, color: Theme.of(context).primaryColor),
                          ),
                          new IconButton(
                            iconSize: 32.0,
                            onPressed: () {
                              setState(() {
                                images.removeAt(index);
                              });
                            },
                            icon: new Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      )
                    ]),
                  ),
                ]),
              );
            }),
      ),
    );
  }

  void _onSendButtonPressed() {
    print('Send button pressed');
  }

  void _onImageButtonPressed(ImageSource source) {
    setState(() {
      ImagePicker.pickImage(source: source).then((newImage) {
        if (newImage != null) {
          setState(() {
            images.add(new RevImage(newImage, 0));
          });
        }
      });
    });
  }
}
