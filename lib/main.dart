import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart' hide Route;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'Proto/mainv2.pb.dart';
import 'Response/ResponseData.dart';
import 'Response/ResponseAuth.dart';
import 'Response/ResponseMatchAuth.dart';

import 'package:yaml/yaml.dart';

// read from application.yml
String _path = 'application.yml';
File _file = File(_path);
String _yamlString = _file.readAsStringSync();
Map yaml = loadYaml(_yamlString);

// extract info from application.yml
String host = yaml['url']['host'];
int portHttp = yaml['url']['port_http'];
int portWs = yaml['url']['port_ws'];

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'WebSocket Raccoon Test';
    return const MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  final _channel = WebSocketChannel.connect(
    //Uri.parse('ws://localhost:6678/socket'),
    Uri.parse('ws://$host:$portWs/socket'),

    //Uri.parse('wss://match.raccoonfantasy.com/socket'),
  );

  @override
  Widget build(BuildContext context) {
    print("Build running");
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Send a message'),
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder(
              stream: _channel.stream,
              builder: (context, snapshot) {
                print('snapshot.data ${snapshot.data}');
                print('snapshot.hasData ${snapshot.hasData}');
                if (snapshot.hasError) {
                  print('Error: ${snapshot.error}');
                  return Text('Error: ${snapshot.error}');
                } else if (snapshot.hasData) {
                  print('snapshot.data! ${snapshot.data}');
                  ServicesResponse response =
                      ServicesResponse.fromBuffer(snapshot.data);
                  return Text('Response: ${response}');
                } else {
                  return const Text('No message');
                }
              },
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _sendMessage() async {
    // request login
    print('request login');
    final responseLogin = await http.post(
      Uri.parse('http://$host:$portHttp/auth/login'),
      // Send authorization headers to the backend.
      //   const body = {
      //     email: payload.email,
      //     password: payload.password
      //   };
      body: jsonEncode(<String, String>{
        'email': 'RC_AM_pippo@gmail.com',
        'password': 'pippo',
      }),
    );
    if (responseLogin.statusCode != 200) {
      return;
    }
    final responseLoginJson = jsonDecode(responseLogin.body);
    ResponseData responseLoginRC = ResponseData.fromJson(responseLoginJson);
    ResponseAuth responseAuth = ResponseAuth.fromJson(responseLoginRC.data);

    await Future.delayed(Duration(seconds: 1));

    // request match auth
    print('request match auth');
    final response = await http.get(
      Uri.parse('http://$host:$portHttp/auth/match-auth'),
      // Send authorization headers to the backend.
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'authorization': responseAuth.access_token,
        //HttpHeaders.authorizationHeader: responseAuth.access_token,
      },
    );

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      final responseJson = jsonDecode(response.body);
      ResponseData responseRC = ResponseData.fromJson(responseJson);
      ResponseMatchAuth responseMatchAuth =
          ResponseMatchAuth.fromJson(responseRC.data);

      await Future.delayed(Duration(seconds: 1));

      // change topic to get auth response
      // ServicesRequest requestChangeTopic = ServicesRequest();
      // String topic = 'auth';
      // requestChangeTopic.route = Route(route: topic);
      // print('change topic to topic: $topic');
      // _channel.sink.add(requestChangeTopic.writeToBuffer());
      //
      // await Future.delayed(Duration(seconds: 1));

      // create request proto
      ServicesRequest servicesRequest = ServicesRequest.create();
      Authenticate authenticate = Authenticate.create();
      String? matchToken = responseMatchAuth.match_token;
      authenticate.token = matchToken.toString();
      servicesRequest.authenticate = authenticate;
      // start sendind request
      print(
          'Start send authenticate request to ws with match token ${servicesRequest.authenticate.token} ');
      _channel.sink.add(servicesRequest.writeToBuffer());
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to request auth');
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }
}
