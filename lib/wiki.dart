import 'dart:io' as IO;
import 'dart:math' as Math;
import 'dart:async' as Async;
import 'dart:convert' as Convert;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'main.dart';

class RevWikiTools {
  static final Uri wikiAPI = Uri.parse('https://revspace.nl/api.php');

  List<IO.Cookie> _sessionCookies;
  IO.HttpClient _wikiClient;
  bool _loggedIn = false;
  String _userName;

  RevWikiTools() {
    _wikiClient = new IO.HttpClient();
    _wikiClient.userAgent = 'RevSpaceApp (Dart ${IO.Platform.version})';
  }

  Async.Future<void> loginFromSecureStorage(Function callback(bool success)) async {
    final FlutterSecureStorage secureStorage = new FlutterSecureStorage();

    return login(
      await secureStorage.read(key: 'wikiUsername'),
      await secureStorage.read(key: 'wikiPassword'),
      callback,
    );
  }

  void login(String username, String password, Function callback(bool success)) {
    // FIXME: this code is written for mediawiki 1.2, it throws warnings
    // about deprecation in 1.28 and might stop working in the near future.
    // See https://www.mediawiki.org/wiki/API:Login for details

    _wikiClient.postUrl(wikiAPI).then((IO.HttpClientRequest request) {
      String data = 'format=json&action=login'
          '&lgname=${Uri.encodeQueryComponent(username)}';
      request.headers.contentType = new IO.ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.headers.contentLength = data.length;
      request.write(data);
      return request.close();
    }).then((IO.HttpClientResponse response) {
      _sessionCookies = response.cookies;
      response.listen((data) {
        String token = Convert.json.decode(new String.fromCharCodes(data))['login']['token'];
        _wikiClient.postUrl(wikiAPI).then((IO.HttpClientRequest request) {
          String data = 'format=json&action=login'
              '&lgname=${Uri.encodeQueryComponent(username)}'
              '&lgpassword=${Uri.encodeQueryComponent(password)}'
              '&lgtoken=${Uri.encodeQueryComponent(token)}';
          request.headers.contentType = new IO.ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
          request.headers.contentLength = data.length;
          request.cookies.addAll(_sessionCookies);
          request.write(data);
          return request.close();
        }).then((IO.HttpClientResponse response) {
          response.listen((data) {
            bool success = Convert.json.decode(new String.fromCharCodes(data))['login']['result'] == 'Success';
            _loggedIn = success;
            _userName = username;
            debugPrint('wiki login() called, succes is $success');
            callback(success);
          });
        });
      });
    });
  }

  Async.Future<List<String>> getAllProjects() async {
    if (!_loggedIn) {
      throw new WikiNotLoggedInException();
    }

    IO.HttpClientRequest request = await _wikiClient.postUrl(wikiAPI);

    String data = 'format=json&action=ask&query=${Uri.encodeQueryComponent(
        '[[Category:Project]]|sort=Project Last Update|order=desc|limit=1000')}';

    request.headers.contentType = new IO.ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.headers.contentLength = data.length;
    request.cookies.addAll(_sessionCookies);
    request.write(data);

    IO.HttpClientResponse response = await request.close();

    Map body = Convert.json.decode(new String.fromCharCodes((await response.toList()).expand((x) => x).toList()));
    Map results = body['query']['results'];

    return results.keys.toList();
  }

  void uploadImage(RevImage im, State state) async {
    const int numChunks = 42;

    String fileName = 'RevSpaceApp_IMG_'
        '${DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-')}.jpg';

    debugPrint('Uploading $im\n as $fileName');

    int chunkSize = (im.resizedJpeg.length / (numChunks - 0.5)).round();


    for (int i = 1; i < numChunks; i++) {
      List<int> chunk = im.resizedJpeg.sublist(i * chunkSize, Math.min((i + 1) * chunkSize, im.resizedJpeg.length));
      int thisChunkSize = chunk.length;

      await new Async.Future.delayed(const Duration(milliseconds: 200)); // FIXME: dummy upload code. lame!

      state.setState(() {
        im.progress = Math.min(im.progress += 0.8 / numChunks, 1.0);
      });
    }
    await new Async.Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('Done! $im');
    state.setState(() {
      im.progress = 1.0;
    });
  }
}

class WikiNotLoggedInException implements Exception {
  final String msg;

  const WikiNotLoggedInException([this.msg]);

  @override
  String toString() => msg ?? 'WikiNotLoggedInException: You have to be logged in before doing this.';
}
