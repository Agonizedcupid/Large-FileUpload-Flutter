import 'dart:io';

import 'package:chunked_uploader/chunked_uploader.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chunk Upload Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Chunk Upload Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<PlatformFile>? _paths;
  String? _extension;
  double progress = 0.0;
  String link = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _pickFiles() async {
    setState(() {
      link = '';
      isLoading = true;
    });
    try {
      _paths = (await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        onFileLoading: (FilePickerStatus status) => print(status),
        allowedExtensions: (_extension?.isNotEmpty ?? false)
            ? _extension?.replaceAll(' ', '').split(',')
            : null,
      ))
          ?.files;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Unsupported operation$e');
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    } finally {
      isLoading = false;

      setState(() {});
    }
  }

  upload() async {
    if (_paths == null) {
      return;
    }
    String fileName = _paths![0].name;
    Stream<List<int>> fileDataStream;

    if (kIsWeb) {
      Uint8List? fileBytes = _paths![0].bytes;
      fileDataStream = Stream.fromIterable([fileBytes!]);
    } else {
      var path = _paths![0].path!;
      var file = File(path);
      fileDataStream = file.openRead();
    }


    //int fileSize = await file.length();
    int fileSize = _paths![0].size;


    String url = 'http://10.10.10.31:28084/api/v1/file/video';
    ChunkedUploader chunkedUploader = ChunkedUploader(
      Dio(
        BaseOptions(
          baseUrl: url,
          headers: {
            'Content-Type': 'multipart/form-data',
            'Connection': 'Keep-Alive',
          },
        ),
      ),
    );
    try {
      Response? response = await chunkedUploader.upload(
        fileKey: "file",
        method: "POST",
        fileDataStream: fileDataStream,
        fileName: fileName,
        fileSize: fileSize,
        //filePath: path,
        maxChunkSize: 500000000,
        path: url,
        data: {
          'additional_data': 'hiii',
          'content_type': 'video' // Add this line
        },
        onUploadProgress: (v) {
          if (kDebugMode) {
            print(v);
          }

          progress = v;
          setState(() {});
        },
      );
      if (kDebugMode) {
        print(response);
      }

      var data = response?.data;
      if (data != null) {
        if (data['status'] == true) {
          link = data['link'];
        }
      } else {
      }
      setState(() {
        _paths = null;
        progress = 0.0;
      });
    } on DioException catch (e) {
      if (kDebugMode) {
        print("DioError: ${e.message}");
        print("DioError Response: ${e.response?.data}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _pickFiles();
              },
              child: const Text('Select File'),
            ),
            const SizedBox(height: 20),
            if ((_paths?.length ?? 0) > 0)
              ElevatedButton(
                onPressed: () {
                  upload();
                },
                child: const Text('Upload'),
              ),
            if (progress > 0)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: LinearPercentIndicator(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  animation: false,
                  lineHeight: 20.0,
                  percent: double.parse(progress.toStringAsExponential(1)),
                  progressColor: Colors.green,
                  center: Text(
                    "${(progress * 100).round()}%",
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (link != '')
              Text(
                link,
                style: const TextStyle(),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
