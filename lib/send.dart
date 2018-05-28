import 'dart:math' as Math;
import 'dart:async' as Async;
import 'dart:isolate' as Isolate;

import 'package:flutter/material.dart';
import 'package:material_search/material_search.dart';
import 'package:image/image.dart' as GFX;

import 'main.dart';
import 'wiki.dart';
import 'settings.dart';

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

  _RevSendState() {
    new Async.Future(() async {
      _wiki.loginFromSecureStorage((success) {
        if (success) {
          _wiki.getAllProjects().then((projects) {
            setState(() {
              _projects = projects;
            });
          });
        } else {
          Navigator.of(context).push(
                new MaterialPageRoute(
                  builder: (context) => new RevSettings(loginFailure: true),
                ),
              );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                final response = new Isolate.ReceivePort();
                Isolate.Isolate.spawn(_imageResizeWorker, response.sendPort);
                response.first.then((first) {
                  final answer = new Isolate.ReceivePort();
                  answer.listen((data) {
                    RevImage im = images[data[1]];
                    setState(() {
                      im.progress = 0.1;
                    });
                    im.resizedJpeg = data[0];
                    if (im != images.last) {
                      // if not the last image, tell the isolate to start resizing the next
                      setState(() {
                        images[data[1] + 1].progress = null;
                      });
                      first.send([images[data[1] + 1], data[1] + 1, answer.sendPort]);
                    }
                    if (im == images.first) {
                      // if the first image, directly start uploading
                      _wiki.uploadImage(im, this);
                    } else {
                      // if not, wait for the previous upload to complete before uploading
                      debugPrint('im ${data[1]} waiting for upload of ${data[1] - 1}!');
                      new Async.Future(() async {
                        while (images[data[1] - 1].progress < 1) {
                          await new Async.Future.delayed(const Duration(milliseconds: 200));
                        }
                      }).then((_null) {
                        _wiki.uploadImage(im, this);
                      });
                    }
                    if (im == images.last) {
                      // if last image, wait untill done
                      new Async.Future(() async {
                        while (images[data[1]].progress < 1) {
                          await new Async.Future.delayed(const Duration(milliseconds: 200));
                        }
                      }).then((_null) {
                        debugPrint('all uploads done! happy now?');
                      });
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

  static void _imageResizeWorker(Isolate.SendPort initialReplyTo) {
    const int maxSizePx = 4000;
    final port = new Isolate.ReceivePort();
    initialReplyTo.send(port.sendPort);

    port.listen((message) {
      final RevImage im = message[0];
      final int i = message[1];
      final Isolate.SendPort send = message[2];

      GFX.Image newImage = GFX.decodeImage(im.file.readAsBytesSync());
      if (Math.max(newImage.width, newImage.height) > maxSizePx) {
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
