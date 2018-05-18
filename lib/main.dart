import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:image_picker/image_picker.dart';

import 'settings.dart';
import 'send.dart';

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

class SelectPhotos extends StatefulWidget {
  @override
  SelectPhotosState createState() {
    selectPhotosState = new SelectPhotosState();
    return selectPhotosState;
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

class SelectPhotosState extends State<SelectPhotos> {
  final GlobalKey<FormState> _selectPhotosFormKey = new GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Select Photos'),
        actions: [
          new IconButton(
            onPressed: () => _onSettingsButtonPressed(),
            tooltip: 'Settings',
            icon: new Icon(Icons.settings),
          ),
        ],
      ),
      body: new Form(
        key: _selectPhotosFormKey,
        onChanged: () => _selectPhotosFormKey.currentState.save(),
        child:
        new ListView.builder(
          padding: const EdgeInsets.only(bottom: 32.0),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return new Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: new Row(children: [
                new RotatedBox(
                  quarterTurns: images[index].rotation,
                  child: new FadeInImage(
                      placeholder: new AssetImage('assets/loading.gif'),
                      image: new RevFileImage(images[index], context),
                      width: 144.0,
                      height: 144.0,
                      fit: BoxFit.cover),
                ),
                new Flexible(
                  child: new Column(children: [
                    new TextFormField(
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                      initialValue: images[index].description,
                      onSaved: (value) => images[index].description = value,
                      validator: (value) {
                        if (value.length == 0) {
                          return 'Please enter a description.';
                        } else if (value.length == 1) {
                          return 'Hey, put in some effort. Please?';
                        } else if (value.length < 10) {
                          return 'Come on, ${value.length} characters is not a description!';
                        }
                        return null;
                      },
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
                            icon: new Icon(Icons.rotate_right, color: Theme
                                .of(context)
                                .primaryColor),
                          ),
                          new IconButton(
                            iconSize: 32.0,
                            onPressed: () {
                              setState(() {
                                images[index].rotation--;
                              });
                            },
                            icon: new Icon(Icons.rotate_left, color: Theme
                                .of(context)
                                .primaryColor),
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
                        ])
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
      bottomNavigationBar: new BottomAppBar(
        color: Theme
            .of(context)
            .primaryColor,
        hasNotch: true,
        child: new Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              new SizedBox(width: 8.0, height: 56.0),
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
            ]),
      ),
      floatingActionButton: (images.length > 0) ? new FloatingActionButton(
        onPressed: () => _onSendButtonPressed(),
        tooltip: 'Send to RevSpace wiki',
        child: new Icon(Icons.send),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }


  void _onSendButtonPressed() {
    if (_selectPhotosFormKey.currentState.validate()) {
      Navigator.of(context).push(
          new MaterialPageRoute(
            builder: (context) => RevSend.getScaffold(images),
          )
      );
    }
  }


  void _onSettingsButtonPressed() async {
    final FlutterSecureStorage secureStorage = new FlutterSecureStorage();
    TextEditingController usernameController = new TextEditingController(
        text: await secureStorage.read(key: 'wikiUsername'));
    TextEditingController passwordController = new TextEditingController(
        text: await secureStorage.read(key: 'wikiPassword'));

    Navigator.of(context).push(
      new MaterialPageRoute(
        builder: (context) => RevSettings.getScaffold(usernameController, passwordController),
      ),
    );
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
