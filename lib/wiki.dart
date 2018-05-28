import 'dart:io' as IO;
import 'dart:math' as Math;
import 'dart:async' as Async;
import 'dart:convert' as Convert;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as Http;
import 'package:http_parser/http_parser.dart' as HttpParser;

import 'main.dart';

class RevWikiClient extends Http.BaseClient {
  final Http.Client _inner = new Http.Client();
  final String ua;

  RevWikiClient(this.ua);

  Async.Future<Http.StreamedResponse> send(Http.BaseRequest request) {
    request.headers['user-agent'] = ua;
    request.headers['cookie'] = RevWikiTools.cookies.join('; ');
    return _inner.send(request);
  }
}

class RevWikiTools {
  static final Uri _wikiURL = Uri.parse('https://revspace.nl/api.php');

  //static final Uri _wikiURL = Uri.parse('http://192.168.111.234/api.php');
  static final String _userAgent = 'RevSpaceApp/${RevSpaceApp.version} (Dart ${IO.Platform.version})';

  static List<String> cookies = [];
  RevWikiClient _wikiClient;
  bool _loggedIn = false;
  String _userName;
  String _csrfToken;

  RevWikiTools() {
    _wikiClient = new RevWikiClient(_userAgent);
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
    // FIXME: this code is written for mediawiki 1.26, it throws warnings
    // about deprecation in 1.28 and might stop working in the near future.
    // See https://www.mediawiki.org/wiki/API:Login for details

    if (!_loggedIn) {
      _wikiClient.post(_wikiURL, body: {
        'format': 'json',
        'action': 'login',
        'lgname': username,
      }).then((response) {
        cookies.add(response.headers['set-cookie'].toString().split(';')[0]);
        String token = Convert.json.decode(response.body)['login']['token'];
        _wikiClient.post(_wikiURL, body: {
          'format': 'json',
          'action': 'login',
          'lgname': username,
          'lgpassword': password,
          'lgtoken': token,
        }).then((response) {
          new RegExp(r'(?:^|,)(\S+?=.+?);').allMatches(response.headers['set-cookie']).forEach((m) {
            cookies.add(m.group(1));
          });
          bool success = Convert.json.decode(response.body)['login']['result'] == 'Success';
          _loggedIn = success;
          _userName = username;
          if (success) {
            _wikiClient.post(_wikiURL, body: {
              'format': 'json',
              'action': 'query',
              'meta': 'tokens',
            }).then((response) {

              _csrfToken = Convert.json.decode(response.body)['query']['tokens']['csrftoken'];
            });
          }
          callback(success);
        });
      });
    }
  }

  Async.Future<List<String>> getAllProjects() async {
    if (!_loggedIn) {
      throw new WikiNotLoggedInException();
    }

    Http.Response response = await _wikiClient.post(_wikiURL, body: {
      'format': 'json',
      'action': 'ask',
      'query': '[[Category:Project]]|sort=Project Last Update|order=desc|limit=1000',
    });

    return Convert.json.decode(response.body)['query']['results'].keys.toList();
  }

  void uploadImage(RevImage im, State state) async {
    const int numChunks = 42;

    String fileName = 'RevSpaceApp_IMG_'
        '${DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-')}.jpg';

    debugPrint('Uploading $im\n as $fileName');

    int chunkSize = (im.resizedJpeg.length / (numChunks - 0.5)).round();

    String fileKey;

    for (int i = 0; i < numChunks; i++) {
      List<int> chunk = im.resizedJpeg.sublist(i * chunkSize, Math.min((i + 1) * chunkSize, im.resizedJpeg.length));
      int thisChunkSize = chunk.length;

      Http.MultipartRequest request = new Http.MultipartRequest('POST', _wikiURL);

      request.headers['user-agent'] = _userAgent;
      request.headers['cookie'] = cookies.join('; ');

      request.fields.addAll({
        'format': 'json',
        'action': 'upload',
        'stash': '1',
        'offset': (i * chunkSize).toString(),
        'token': _csrfToken,
        'filename': fileName,
        'filesize': im.resizedJpeg.length.toString(),
      });
      if (fileKey != null) {
        request.fields['filekey'] = fileKey;
      }

      request.files.add(new Http.MultipartFile.fromBytes(
        'chunk',
        chunk,
        filename: fileName,
        contentType: new HttpParser.MediaType('image', 'jpeg'),
      ));

      Http.StreamedResponse response = await request.send();

      Map responseBody = Convert.jsonDecode(
        new String.fromCharCodes((await response.stream.toList()).expand((x) => x).toList()),
      );

      fileKey = responseBody['upload']['filekey'];
      String result = responseBody['upload']['result'];

      state.setState(() {
        im.progress = Math.min(im.progress += 0.8 / numChunks, 1.0);
      });
      if (result == 'Success') {
        Http.MultipartRequest request = new Http.MultipartRequest('POST', _wikiURL);

        request.headers['user-agent'] = _userAgent;
        request.headers['cookie'] = cookies.join('; ');

        request.fields.addAll({
          'format': 'json',
          'action': 'upload',
          'token': _csrfToken,
          'filename': fileName,
          'filekey': fileKey,
          'comment': '${im.description}\n\nUploaded using $_userAgent',
          'text': '${im.description}\n\nUploaded using $_userAgent',
        });

        Http.StreamedResponse response = await request.send();

        Map responseBody = Convert.jsonDecode(
          new String.fromCharCodes((await response.stream.toList()).expand((x) => x).toList()),
        );
      }
    }

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
