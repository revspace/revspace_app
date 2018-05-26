import 'dart:math';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:material_search/material_search.dart';
import 'package:image/image.dart' as GFX;

import 'main.dart';
import 'wiki.dart';

class RevSend extends StatefulWidget {
  static const String routeName = '/send';

  @override
  _RevSendState createState() => new _RevSendState();
}

class _RevSendState extends State<RevSend> {
  static RevWikiTools _wiki = new RevWikiTools();
  static List<String> _projects = ['Loading...'];
  static String _selectedProject;

  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    _wiki.loginFromSecureStorage((success) {
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
                  new LinearProgressIndicator(
                    value: im.progress,
                  ),
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
                final response = new ReceivePort();
                Isolate.spawn(_imageResizeWorker, response.sendPort);
                response.first.then((first) {
                  final answer = new ReceivePort();
                  answer.listen((data) {
                    RevImage im = images[data[1]];
                    setState(() {
                      im.progress = 0.1;
                    });
                    im.resizedJpeg = data[0];
                    if (im != images.last) {
                      data[1]++;
                      RevImage nextIm = images[data[1]];
                      nextIm.progress = null;
                      first.send([nextIm, data[1], answer.sendPort]);
                    }
                  });
                  setState(() {
                    images[0].progress = null;
                  });
                  first.send([images[0], 0, answer.sendPort]);
                });
              },
            )
          : null,
    );
  }

  static void _imageResizeWorker(SendPort initialReplyTo) {
    const int maxSizePx = 4000;
    final port = new ReceivePort();
    initialReplyTo.send(port.sendPort);

    port.listen((message) {
      final RevImage im = message[0];
      final int i = message[1];
      final SendPort send = message[2];

      GFX.Image newImage = GFX.decodeImage(im.file.readAsBytesSync());
      if (max(newImage.width, newImage.height) > maxSizePx) {
        newImage = GFX.copyResize(newImage, maxSizePx);
      }
      int actualRotation = im.rotation % 4 * 90;
      if (actualRotation != 0) {
        newImage = GFX.copyRotate(newImage, actualRotation);
      }
      List<int> data = GFX.encodeJpg(newImage, quality: 75);
      debugPrint('encoded: ${data.length / 1024} kB from ${im.file
          .readAsBytesSync()
          .length / 1024 } kB original');
      send.send([data, i]);
    });
  }
}
