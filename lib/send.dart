import 'dart:math';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:material_search/material_search.dart';
import 'package:image/image.dart' as GFX;

import 'main.dart';
import 'wiki.dart';

class RevSend {
  static RevWikiTools _wiki = new RevWikiTools();
  static List<String> _projects = ['Loading...'];
  static String _selectedProject;

  static final GlobalKey<FormState> _sendFormKey = new GlobalKey<FormState>();
  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  static Scaffold getScaffold() {
    _wiki.loginFromSecureStorage((success) {
      print('suc: $success');
      if (success) {
        _wiki.getAllProjects().then((projects) {
          _projects = projects;
        });
      } else {
        Navigator.of(_scaffoldKey.currentContext).pop();
      }
    });

    List<Card> imagesList = new List<Card>();
    images.forEach((im) {
      imagesList.add(new Card(
        margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
        child: new Row(
          children: [
            new RotatedBox(
              quarterTurns: im.rotation,
              child: new FadeInImage(
                  placeholder: new AssetImage('assets/loading.gif'),
                  image: new RevFileImage(im, _scaffoldKey.currentContext),
                  width: 64.0,
                  height: 64.0,
                  fit: BoxFit.cover),
            ),
            new SizedBox(width: 16.0),
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  new Text(im.description),
                  new LinearProgressIndicator(),
                ],
              ),
            ),
            new SizedBox(width: 16.0),
          ],
        ),
      ));
    });

    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: new Text('Send to RevSpace Wiki'),
      ),
      body: new SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 80.0),
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24.0),
            new Text('The app will automatically add your pictures to the bottom of the wiki page of your project. '
                'Please select your project below.'),
            const SizedBox(height: 24.0),
            new MaterialSearchInput<String>(
              placeholder: 'Find your existing project page',
              results: _projects
                  .map((name) => new MaterialSearchResult<String>(
                        value: name,
                        text: name,
                        icon: Icons.find_in_page,
                      ))
                  .toList(),
              onSelect: (selection) {
                _selectedProject = selection;
              },
            ),
            const SizedBox(height: 24.0),
            new Column(children: imagesList),
          ],
        ),
      ),
      floatingActionButton: (_selectedProject != null)
          ? new FloatingActionButton(
              child: new Icon(Icons.send),
              onPressed: () {
                print('FAB pressed, project: $_selectedProject, images: ${images.length}');

                final response = new ReceivePort();
                Isolate.spawn(_imageResizeWorker, response.sendPort);
                response.first.then((first) {
                  final answer = new ReceivePort();
                  first.send([images, answer.sendPort]);
                  answer.first.then((first) {
                    print('answer: $first');
                  });
                });

                //Isolate.spawn(_imageResizeWorker, new ReceivePort().sendPort..send(images));
              },
            )
          : null,
    );
  }

  static void _imageResizeWorker(SendPort initialReplyTo) {
    const int maxSizePx = 4000;
    print('Hello from isolate');
    final port = new ReceivePort();
    initialReplyTo.send(port.sendPort);

    port.listen((message) {
      final data = message[0] as List<RevImage>;
      final send = message[1] as SendPort;

      data.forEach((im) {
        print('processing $im');
        GFX.Image image = GFX.decodeImage(im.file.readAsBytesSync());
        if (max(image.width, image.height) > maxSizePx) {
          image = GFX.copyResize(image, maxSizePx);
          print('resized');
        }
        print('original  : ${(im.file
            .readAsBytesSync()
            .length / 1024 / 1024).toStringAsFixed(3)}');
        print('resized 90: ${(GFX
            .encodeJpg(image, quality: 90)
            .length / 1024 / 1024).toStringAsFixed(3)}');
        print('resized 60: ${(GFX
            .encodeJpg(image, quality: 60)
            .length / 1024 / 1024).toStringAsFixed(3)}');
        send.send('from isolate: done!');
      });
    });
  }
}
