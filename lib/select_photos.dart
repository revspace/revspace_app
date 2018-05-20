import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'settings.dart';
import 'send.dart';


class SelectPhotos extends StatefulWidget {
  @override
  SelectPhotosState createState() {
    selectPhotosState = new SelectPhotosState();
    return selectPhotosState;
  }
}

class SelectPhotosState extends State<SelectPhotos> {
  final FlutterSecureStorage _secureStorage = new FlutterSecureStorage();
  final GlobalKey<FormState> _selectPhotosFormKey = new GlobalKey<FormState>();
  bool _firstRun = true;

  @override
  Widget build(BuildContext context) {
    _secureStorage.read(key: 'wikiUsername').then((value) {
      setState(() {
        _firstRun = (value == null);
      });
    });

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
        child: _firstRun ?
        new Card(
          margin: const EdgeInsets.all(16.0),
          child: new Container(
            margin: const EdgeInsets.all(8.0),
            child: new Text('You are running this app for the first time.\n\n'
                'Please go to settings (top-right) to setup your RevSpace wiki account before uploading.'),
          ),
        ) :
        new ListView.builder(
          padding: const EdgeInsets.only(top: 8.0, bottom: 32.0),
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
            builder: (context) => RevSend.getScaffold(),
          )
      );
    }
  }

  void _onSettingsButtonPressed() async {
    TextEditingController usernameController = new TextEditingController(
        text: await _secureStorage.read(key: 'wikiUsername'));
    TextEditingController passwordController = new TextEditingController(
        text: await _secureStorage.read(key: 'wikiPassword'));

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
