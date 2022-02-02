import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1922 實聯制掃描器',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool flashlightOn = false;
  String? lastCode;

  // hot reload
  @override
  void reassemble() {
    super.reassemble();
    try {
      if (Platform.isAndroid) {
        controller?.pauseCamera();
      }
      controller?.resumeCamera();
    } catch (e) {
      // ignore
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
    controller.getFlashStatus().then((value) {
      if (value != null) {
        setState(() {
          flashlightOn = value;
        });
      }
    });
  }

  Future<bool> _send1922SMS(String message) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (Platform.isIOS) {
      /// IOS 版尚未支援直接在背景發送訊息
      await launch('sms:1922?body=$message');
      return true;
    } else {
      final Telephony telephony = Telephony.instance;

      bool permissionsGranted = await telephony.requestSmsPermissions ?? false;

      if (permissionsGranted) {
        await telephony.sendSms(to: "1922", message: message);
      }

      return permissionsGranted;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("台灣 1922 實聯制掃描器"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              // TODO: about page
            },
            tooltip: "關於本軟體",
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _buildQRView(),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Builder(builder: (context) {
                  double fontSize = 20;
                  if (result != null) {
                    String spilt = "smsto:1922:";
                    String? code = result?.code;
                    String? formattedCode = code?.replaceFirst(spilt, "");
                    Text successText = Text("實聯制簡訊發送成功！",
                        style:
                            TextStyle(fontSize: fontSize, color: Colors.green));

                    if (lastCode == code) {
                      return successText;
                    }

                    if (code != null &&
                        code.startsWith(spilt) &&
                        formattedCode != null) {
                      lastCode = code;

                      WidgetsBinding.instance!
                          .addPostFrameCallback((timeStamp) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return FutureBuilder(
                                future: _send1922SMS(formattedCode),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    if (snapshot.data == true) {
                                      return AlertDialog(
                                        title: successText,
                                        actions: [
                                          TextButton(
                                            child: const Text("確定"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    } else {
                                      return AlertDialog(
                                        title: Text(
                                            "由於您尚未授予本程式發送簡訊的權限，因此發送實聯制簡訊失敗，請授予權限後再試。",
                                            style: TextStyle(
                                                fontSize: fontSize,
                                                color: Colors.red)),
                                        actions: [
                                          TextButton(
                                            child: const Text("確定"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                  } else {
                                    return AlertDialog(
                                      title: Text("實聯制簡訊發送中...",
                                          style: TextStyle(
                                              fontSize: fontSize,
                                              color: Colors.orange)),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          CircularProgressIndicator()
                                        ],
                                      ),
                                    );
                                  }
                                },
                              );
                            });
                      });

                      return successText;
                    } else {
                      return Text("無效的實聯制 QR Code",
                          style:
                              TextStyle(color: Colors.red, fontSize: fontSize));
                    }
                  } else {
                    return Text("請將實聯制 QR Code 放置於框內掃描",
                        style: TextStyle(fontSize: fontSize));
                  }
                }),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                        onPressed: () {
                          setState(() {
                            flashlightOn = !flashlightOn;
                          });
                          controller?.toggleFlash();
                        },
                        icon: Icon(flashlightOn
                            ? Icons.flashlight_on
                            : Icons.flashlight_off),
                        label: Text(flashlightOn ? "關閉手電筒" : "開啟手電筒")),
                    TextButton.icon(
                        onPressed: () {
                          launch("sms:1922");
                        },
                        icon: const Icon(Icons.history),
                        label: const Text("查看發送紀錄"))
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  QRView _buildQRView() {
    Size size = MediaQuery.of(context).size;
    double scanArea = (size.width < 400 || size.height < 400) ? 150.0 : 300.0;

    void onPermissionSet(QRViewController controller, bool permission) {
      if (!permission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('掃描實聯制 QR Code 需要相機存取權限')),
        );
      }
    }

    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (controller, permission) =>
          onPermissionSet(controller, permission),
    );
  }
}
