// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:http_client/console.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrcode_reader/QRCodeReader.dart';
import 'dart:convert';

void main() {
  runApp(new BaseApp());
}

class BaseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'ImageShare',
      home: new BasePage(title: 'ImageShare'),
    );
  }
}

class BasePage extends StatefulWidget {
  BasePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _BasePageState createState() => new _BasePageState();
}

class _BasePageState extends State<BasePage> {
  File imageFile;
  String barcodeString;
  String server;
  final GlobalKey<ScaffoldState> _scaffoldstate = new GlobalKey<ScaffoldState>();

  @override
  initState() {
    super.initState();
  }

  void showSnackBar(String value) {
    _scaffoldstate.currentState.showSnackBar(new SnackBar(
      content: new Text(value),
      duration: new Duration(seconds: 2),
    ));
  }

  Future<bool> showAlertDialog(String title, String content) async{
    var alert = new AlertDialog(
        title: new Text(title),
        content: new Text(content),
        actions: <Widget>[
          new FlatButton(
            child: new Text('Yes'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          new FlatButton(
            child: new Text('No'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
        ]
    );
    return showDialog(context: context, child: alert);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = new Center(
      child: new RaisedButton(
        child: const Text('Connect to a new Server'),
        color: Theme.of(context).accentColor,
        elevation: 4.0,
        splashColor: Colors.blueGrey,
        onPressed: () {
          scanQR();
        },
      ),
    );
    return new Scaffold(
      key: _scaffoldstate,
      appBar: new AppBar(
        title: const Text('ImageShare'),
      ),

      body: body,
      floatingActionButton:
            new FloatingActionButton(
              onPressed: () {
               pickImage();
              },
              tooltip: 'Pick Image',
              child: new Icon(Icons.add_a_photo),
            ),
    );
  }
  
  Future delay() async{
    return new Future.delayed(new Duration(milliseconds: 500));
  }

  void pickImage() async{
    if(server!=null) {
      imageFile = await ImagePicker.pickImage();
      await delay();
      sendHTTPFile(server, imageFile);
    } else {
      showSnackBar("No server chosen!");
    }
  }
  
  void scanQR() async{
    var setServer = true;
    if(server!=null){
      setServer = await showAlertDialog("Already connected", "Do you want to connect to a new server?");
    }
    if(setServer) {
      barcodeString = await new QRCodeReader().scan();
      await delay();
      //Check QR-Code-String
      String regex = r"(http(?:s|)):\/\/([a-z0-9.-]+):([0-9]+)([a-zA-Z\/+-]*|)\?.*key=([a-f0-9]{16})(\&\S*)*$";
      RegExp r = new RegExp(regex);
      var matches = r.allMatches(barcodeString);
      print(matches);
      if(matches.length == 0) {
        showSnackBar("The scanned QR-Code is invalid");
      } else {
        server = barcodeString;
  }
    }
  }
  void sendHTTPFile(String url, File file) async{
    try {
      var bytes = file.readAsBytesSync();
      var base64 = BASE64.encode(bytes);
      print(url);
      var body = {"fileformat":file.path.split(".").last,"content":base64};
      var jsonBody = JSON.encode(body);
      final client = new ConsoleClient();
      final rs = await client.send(new Request('POST', url,body: jsonBody));
      final textContent = await rs.readAsString();
      if(textContent!="success"){
        if(textContent=="invalid_session"){
          showSnackBar("The session expired, please re-connect to the server");
        } else {
          showSnackBar("Unexpected problem while sending");
        }
      } else {
        showSnackBar("Successfully send the image");
      }
      await client.close();
    } catch(exception, stackTrace) {
      print(exception);
      print(stackTrace);
      showSnackBar("Couldn't send the image, maybe the server is offline?");
    }
  }
}