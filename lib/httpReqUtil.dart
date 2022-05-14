import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class HttpReqUtil {
  void postFile(File f) async {
    String name = basename(f.path);
    var url = Uri.parse('http://192.168.6.106/upload/' + name);
    var response = http.post(url, body: f.readAsBytesSync());
    response.asStream().first;
  }

  static HttpClient getHttpClient() {
    HttpClient httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    return httpClient;
  }

  static void fileUpload(File file) async {
    String name = basename(file.path);
    String url = 'http://192.168.6.106/upload/' + name;
    final fileStream = file.openRead();
    int totalByteLength = file.lengthSync();
    final httpClient = getHttpClient();
    final request = await httpClient.postUrl(Uri.parse(url));
    request.contentLength = totalByteLength;
    int byteCount = 0;
    Stream<List<int>> streamUpload = fileStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          byteCount += data.length;
          print("" +
              byteCount.toString() +
              "      " +
              totalByteLength.toString());
          sink.add(data);
        },
        handleError: (error, stack, sink) {
          print(error.toString());
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
    await request.addStream(streamUpload);
    final httpResponse = await request.close();
  }

  Future<http.Response> getList() async {
    var url = Uri.parse('http://192.168.6.106/');
    var response = await http.get(url);
    return response;
  }

  Future<http.Response> deleteItem(String s) async {
    var url = Uri.parse('http://192.168.6.106/delete/' + s);
    var response = await http.post(url);
    return response;
  }

  Future<http.Response> playItem(String s) async {
    var url = Uri.parse('http://192.168.6.106/play/' + s);
    var response = await http.post(url);
    return response;
  }

  Future<http.Response> pauseItem(String s) async {
    var url = Uri.parse('http://192.168.6.106/pause/' + s);
    var response = await http.post(url);
    return response;
  }
}
