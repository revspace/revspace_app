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
    request.headers['cookie'] = RevWikiTools.getCookies();
    return _inner.send(request);
  }
}

class RevWikiTools {
  //static final Uri _wikiURL = Uri.parse('https://revspace.nl/api.php');
  static final Uri _wikiURL = Uri.parse('http://192.168.111.234/api.php');

  static final String _userAgent = 'RevSpaceApp/${RevSpaceApp.version} (Dart ${IO.Platform.version})';

  static Map<String, String> cookies = {};
  RevWikiClient _wikiClient;
  bool _loggedIn = false;
  String _userName;
  String _csrfToken;

  RevWikiTools() {
    _wikiClient = new RevWikiClient(_userAgent);
  }

  static String getCookies() {
    String result = '';
    cookies.forEach((k, v) {
      result += '$k=$v; ';
    });
    // result.substring(0, Math.max(0, result.length - 2));
    return result;
  }

  static Http.MultipartRequest _getMultipartRequest() {
    Http.MultipartRequest request = new Http.MultipartRequest('POST', _wikiURL);

    request.headers['user-agent'] = _userAgent;
    request.headers['cookie'] = '';
    request.headers['cookie'] = getCookies();

    return request;
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
        new RegExp(r'(?:^|,)(\S+?)=(\S+?);').allMatches(response.headers['set-cookie']).forEach((m) {
          cookies[m.group(1)] = m.group(2);
        });
        String token = Convert.json.decode(response.body)['login']['token'];
        _wikiClient.post(_wikiURL, body: {
          'format': 'json',
          'action': 'login',
          'lgname': username,
          'lgpassword': password,
          'lgtoken': token,
        }).then((response) {
          new RegExp(r'(?:^|,)(\S+?)=(\S+?);').allMatches(response.headers['set-cookie']).forEach((m) {
            cookies[m.group(1)] = m.group(2);
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

    im.fileNameOnWiki = 'RevSpaceApp_IMG_'
        '${DateTime.now().toIso8601String().replaceAll('T', '_').replaceAll(':', '-')}.jpg';

    int chunkSize = (im.resizedJpeg.length / (numChunks - 0.5)).round();

    String fileKey;

    for (int i = 0; i < numChunks; i++) {
      List<int> chunk = im.resizedJpeg.sublist(i * chunkSize, Math.min((i + 1) * chunkSize, im.resizedJpeg.length));
      int thisChunkSize = chunk.length;

      Http.MultipartRequest request = _getMultipartRequest();

      request.fields.addAll({
        'format': 'json',
        'action': 'upload',
        'stash': '1',
        'offset': (i * chunkSize).toString(),
        'token': _csrfToken,
        'filename': im.fileNameOnWiki,
        'filesize': im.resizedJpeg.length.toString(),
      });
      if (fileKey != null) {
        request.fields['filekey'] = fileKey;
      }

      request.files.add(new Http.MultipartFile.fromBytes(
        'chunk',
        chunk,
        filename: im.fileNameOnWiki,
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
        Http.MultipartRequest request = _getMultipartRequest();

        request.fields.addAll({
          'format': 'json',
          'action': 'upload',
          'token': _csrfToken,
          'filename': im.fileNameOnWiki,
          'filekey': fileKey,
          'comment': '${im.description}\n\nUploaded using [[RevSpace App]] ${RevSpaceApp.version}',
          'text': '${im.description}\n\nUploaded using [[RevSpace App]] ${RevSpaceApp.version}',
        });

        Http.StreamedResponse response = await request.send();

        Map responseBody = Convert.jsonDecode(
          new String.fromCharCodes((await response.stream.toList()).expand((x) => x).toList()),
        );

        if (responseBody['upload']['result'] == 'Warning') {
          if (responseBody['upload'].containsKey('warnings')) {
            if (responseBody['upload']['warnings'].containsKey('duplicate')) {
              im.fileNameOnWiki = responseBody['upload']['warnings']['duplicate'][0];
            } else if (responseBody['upload']['warnings'].containsKey('duplicate-archive')) {
              debugPrint('Duplicate-archive! '
                  '${im.fileNameOnWiki} == ${responseBody['upload']['warnings']['duplicate-archive']}');
              // TODO: handle duplicates of previously removed images.
              /* 'The photo "${im.description}" has already been uploaded to the wiki in the past '
                 'and has been deleted. Unfortunately, we cannot re-upload previously deleted photos. '
                 'Please contact a wiki administrator if you need further assistance.' */
            }
          }
        }
      }
    }

    state.setState(() {
      im.progress = 1.0;
    });
  }

  void editWiki(String pageName, List<RevImage> images) async {
    String text = '\n\n----\n'
        'Photos added using the [[RevSpace App]] ${RevSpaceApp.version} on '
        '${DateTime.now().toIso8601String().replaceAll('T', ' at ').split('.')[0]}\n'
        '<gallery>\n';

    images.forEach((im) {
      text += '${im.fileNameOnWiki}|${im.description}\n';
    });

    text += '<\/gallery>';

    Http.Response response = await _wikiClient.post(_wikiURL, body: {
      'format': 'json',
      'action': 'edit',
      'token': _csrfToken,
      'title': pageName,
      'summary': 'Added ${images.length} photo${(images.length > 1) ? 's' : ''}'
          ' using [[RevSpaceApp]] ${RevSpaceApp.version}',
      'bot': 'true',
      'appendtext': text,
    });
  }
}

class WikiNotLoggedInException implements Exception {
  final String msg;

  const WikiNotLoggedInException([this.msg]);

  @override
  String toString() => msg ?? 'WikiNotLoggedInException: You have to be logged in before doing this.';
}
