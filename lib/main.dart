import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_file_list_flutter/audio_device.dart';
import 'package:http_file_list_flutter/device_card.dart';
import 'package:http_file_list_flutter/portscanner.dart';
import 'package:http_file_list_flutter/song_card.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';

import 'httpReqUtil.dart';
import 'song.dart';

void setIp(String ip) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ip', ip);
}

void getIp() async {
  // Obtain shared preferences.
  final prefs = await SharedPreferences.getInstance();

  // Try reading data from the 'counter' key. If it doesn't exist, returns null.
  final String? counter = prefs.getString('ip');
  if (counter != null) {
    print("" + counter.toString());
    HttpReqUtil.baseAddr = counter;
  }
}

List<String> ips = [];
RawDatagramSocket? mySocket;

Future printIps() async {
  ips.clear();
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      final n = addr.address;
      final a = n.lastIndexOf(".");
      final b = n.substring(0, a + 1);
      ips.add(b + "0/24");
    }
  }
}

final scanner = Scanner();

Future scanTcp() {
  List<String> foundPorts = [];
  List<Future> connectionFutures = [];
  for (var ip in ips) {
    connectionFutures.add(scanner.scanPortRange(ip).then((result) {
      foundPorts.addAll(result);
    }));
  }

  Completer completer = new Completer();
  Future.wait(connectionFutures).then((allSockets) {
    completer.complete(foundPorts);
  });
  return completer.future;
}

void main() {
  getIp();
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('网络音频');
    setWindowMinSize(const Size(900, 700));
    setWindowMaxSize(Size.infinite);
  }
  runApp(const MyApp());

  int port = 8082;
  RawDatagramSocket.bind(InternetAddress.anyIPv4, port).then((socket) {
    mySocket = socket;
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = socket.receive();
        if (dg == null) return;
        final recvd = String.fromCharCodes(dg.data);
        if (recvd.startsWith("xvacax"))
          print("$recvd from ${dg.address.address}:${dg.port}");
      }
    });
    // socket.send(
    //     Utf8Codec().encode("vaca"), InternetAddress("192.168.6.109"), 8889);
  });
  printIps();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const vaca(),
    );
  }
}

class vaca extends StatefulWidget {
  const vaca({Key? key}) : super(key: key);

  @override
  State<vaca> createState() => _vacaState();
}

class _vacaState extends State<vaca> {
  List<Song> song = [];
  List<AudioDevice> audioDevice = [];
  HttpReqUtil httpUtils = HttpReqUtil();
  double _currentSliderValue = 60;
  bool rightViewVisibility = false;
  double downloadProgress = 0;
  bool dispDownload = false;

  final ScrollController _scrollController = ScrollController();

  List<Widget> dispSongList() {
    List<Widget> result = song
        .map((quote) => SongWidget(
              song: quote,
              delete: () {
                delList(quote.text);
              },
              play: () {
                playList(quote.text, quote.isPlay);
              },
            ))
        .toList();
    return result;
  }

  List<Widget> dispDeviceList() {
    List<Widget> result = audioDevice
        .map((quote) => DeviceWidget(
              song: quote,
              play: () {
                selectList(quote.text);
              },
            ))
        .toList();
    return result;
  }

  void pickFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      print(result.files.length);

      for (int k = 0; k < result.files.length; k++) {
        File file = File(result.files[k].path!);
        await HttpReqUtil.fileUpload(file, (a, b) {
          if (dispDownload == false) {
            setState(() {
              downloadProgress = a.toDouble() / b.toDouble();
              dispDownload = true;
            });
          }
          setState(() {
            downloadProgress = a.toDouble() / b.toDouble();
          });
          print("" + a.toString() + "      " + b.toString());

          if (a == b) {
            setState(() {
              dispDownload = false;
            });
          }
        });
        await Future.delayed(Duration(microseconds: 300));
        getMyList();
        await Future.delayed(Duration(microseconds: 300));
      }
    }
  }

  void pickFilePlay() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      HttpReqUtil.postFilePlay(file);
    }
  }

  void getMyList() async {
    try {
      var result = await httpUtils.getList();
      String body = utf8.decode(result.bodyBytes);
      List<dynamic> tagsJson = jsonDecode(body);
      song.clear();
      for (int k = 0; k < tagsJson.length; k++) {
        song.add(Song(text: tagsJson[k], author: ""));
      }
    } catch (e) {
      // song.clear();
    }

    if (HttpReqUtil.baseAddr.isEmpty) {
      setState(() {
        rightViewVisibility = false;
      });
    } else {
      setState(() {
        rightViewVisibility = true;
      });
    }

    setState(() {});
  }

  void delList(String s) async {
    var result = await httpUtils.deleteItem(s);
    String body = utf8.decode(result.bodyBytes);
    List<dynamic> tagsJson = jsonDecode(body);
    print(tagsJson.length);
    song.clear();
    for (int k = 0; k < tagsJson.length; k++) {
      song.add(Song(text: tagsJson[k], author: ""));
    }
    setState(() {});
  }

  void volume(String s) async {
    var result = await httpUtils.volumeItem(s);
    String body = utf8.decode(result.bodyBytes);
    List<dynamic> tagsJson = jsonDecode(body);
    print(tagsJson.length);
    song.clear();
    for (int k = 0; k < tagsJson.length; k++) {
      song.add(Song(text: tagsJson[k], author: ""));
    }
    setState(() {});
  }

  void volumeInt(int s) async {
    List<int> bufer = [118, 97, 99, 97, s];
    mySocket?.send(bufer, InternetAddress(HttpReqUtil.baseAddr), 8889);
  }

  void playList(String s, bool isPlay) async {
    if (isPlay) {
      var result = await httpUtils.pauseItem(s);
      String body = utf8.decode(result.bodyBytes);
      List<dynamic> tagsJson = jsonDecode(body);
      print(tagsJson.length);
      song.clear();
      for (int k = 0; k < tagsJson.length; k++) {
        song.add(Song(text: tagsJson[k], author: "", isPlay: false));
      }
    } else {
      var result = await httpUtils.playItem(s);
      String body = utf8.decode(result.bodyBytes);
      List<dynamic> tagsJson = jsonDecode(body);
      print(tagsJson.length);
      song.clear();
      for (int k = 0; k < tagsJson.length; k++) {
        if (tagsJson[k] == s) {
          song.add(Song(text: tagsJson[k], author: "", isPlay: true));
        } else {
          song.add(Song(text: tagsJson[k], author: "", isPlay: false));
        }
      }
    }

    setState(() {});
  }

  void selectList(String s) async {
    HttpReqUtil.baseAddr = s;
    _controller.text = s;
    getMyList();
  }

  void fuckDevice(List<String> a) {
    audioDevice.clear();
    for (var k in a) {
      audioDevice.add(AudioDevice(text: k));
    }
    setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = TextEditingController();
    _controller.text = HttpReqUtil.baseAddr;
  }

  late TextEditingController _controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [
                Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                              onPressed: () {
                                scanTcp().then((value) => fuckDevice(value));
                              },
                              icon: Icon(Icons.search),
                              label: Text('扫描设备')),
                        ],
                      ),
                    )
                  ],
                ),
                Expanded(
                    child: ListView(
                  children: dispDeviceList(),
                )),
              ],
            ),
          ),
          Visibility(
            visible: rightViewVisibility,
            child: SizedBox(
              width: 350,
              child: Column(
                children: [
                  Column(
                    children: <Widget>[
                      TextField(
                        enabled: false,
                        autofocus: true,
                        controller: _controller,
                        decoration: const InputDecoration(
                            labelText: "设备IP地址",
                            hintText: "输入ip地址",
                            prefixIcon: Icon(Icons.network_wifi)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                              onPressed: () {
                                getMyList();
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('刷新')),
                          Slider(
                            value: _currentSliderValue,
                            max: 100,
                            divisions: 100,
                            onChanged: (double value) {
                              setState(() {
                                //  volume(value.toInt().toString());
                                _currentSliderValue = value;
                              });
                            },
                            onChangeEnd: (double value) {
                              setState(() {
                                print(value);
                                volumeInt(value.toInt());
                                // var a = _currentSliderValue = value;
                              });
                            },
                          ),
                          const Text(
                            "音量",
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                            onPressed: () {
                              pickFile();
                            },
                            icon: Icon(Icons.cloud_upload),
                            label: Text('上传歌曲')),
                        ElevatedButton.icon(
                            onPressed: () {
                              pickFilePlay();
                            },
                            icon: Icon(Icons.pages),
                            label: Text('实时播放')),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: dispDownload,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: FittedBox(
                        child: LinearPercentIndicator(
                          width: 240.0,
                          lineHeight: 20.0,
                          percent: downloadProgress,
                          center: Text(
                            "${(downloadProgress * 100).toStringAsFixed(1)}%",
                            style:
                                TextStyle(fontSize: 12.0, color: Colors.white),
                          ),
                          barRadius: Radius.circular(20),
                          backgroundColor: Colors.grey,
                          progressColor: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                      child: Scrollbar(
                    controller: _scrollController,
                    isAlwaysShown: true,
                    child: ListView(
                      controller: _scrollController,
                      children: dispSongList(),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
