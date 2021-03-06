import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:implulsnew/bt/widgets.dart';
import 'package:implulsnew/styles/button.dart';

const String ekg_UUID = "00b3b2ae-928b-11e9-bc42-526af7764f64";


class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothState>(
      stream: FlutterBlue.instance.state,
      initialData: BluetoothState.unknown,
      builder: (c, snapshot) {
        final state = snapshot.data;
        if (state == BluetoothState.on) {
          return FindDevicesScreen();
        }
        return BluetoothOffScreen(state: state);
      },
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle2
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Devices List - USE SET'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 3))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return RaisedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            r.device.connect();
                            return DeviceScreen(device: r.device);
                          })),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

const AsciiCodec ascii = AsciiCodec();
var _writeInput = 'on';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _writeToDeviceBytes() {
    return ascii.encode(_writeInput).toList();
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
//                      await c.write(_getRandomBytes(), withoutResponse: true);
                      await c.write(_writeToDeviceBytes(),
                          withoutResponse: true);
                      print(c.write(_writeToDeviceBytes()));
                      print(_writeToDeviceBytes());
                      await c.read();
                      print(c.read());
                      c.value.listen((scanResult) {
//                        Text('$scanResult');
                        print('${device.name} found! write: $scanResult');
                      });
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
//                      await c.read();
//                      c.value.listen((scanResult) {
////                        Text('$scanResult');
//                        print('${device.name} found! notify: $scanResult');
//                        print("$_getRandomBytes()");
//                      });
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () =>
                                d.write(_writeToDeviceBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(device.name),
          actions: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) {
                VoidCallback onPressed;
                String text;
                switch (snapshot.data) {
                  case BluetoothDeviceState.connected:
                    onPressed = () => device.disconnect();
                    text = 'DISCONNECT';
                    break;
                  case BluetoothDeviceState.disconnected:
                    onPressed = () => device.connect();
                    text = 'CONNECT';
                    break;
                  default:
                    onPressed = null;
                    text = snapshot.data.toString().substring(21).toUpperCase();
                    break;
                }
                return FlatButton(
                    onPressed: onPressed,
                    child: Text(
                      text,
                      style: Theme.of(context)
                          .primaryTextTheme
                          .button
                          .copyWith(color: Colors.white),
                    ));
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<BluetoothDeviceState>(
                stream: device.state,
                initialData: BluetoothDeviceState.connecting,
                builder: (c, snapshot) => ListTile(
                  leading: (snapshot.data == BluetoothDeviceState.connected)
                      ? Icon(Icons.bluetooth_connected)
                      : Icon(Icons.bluetooth_disabled),
                  title: Text(
                      'Device is ${snapshot.data.toString().split('.')[1]}. Push right icon to refesh services'),
                  subtitle: Text('${device.id}'),
                  trailing: StreamBuilder<bool>(
                    stream: device.isDiscoveringServices,
                    initialData: false,
                    builder: (c, snapshot) {
                      return IndexedStack(
                        index: snapshot.data ? 1 : 0,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () => device.discoverServices(),
                          ),
                          IconButton(
                            icon: SizedBox(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.grey),
                              ),
                              width: 18.0,
                              height: 18.0,
                            ),
                            onPressed: null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              StreamBuilder<int>(
                stream: device.mtu,
                initialData: 0,
                builder: (c, snapshot) => ListTile(
                  title: Text('MTU Size'),
                  subtitle: Text('${snapshot.data} bytes'),
//                trailing: IconButton(
//                  icon: Icon(Icons.edit),
//                  onPressed: () => device.requestMtu(223),
//                ),
                ),
              ),
              StreamBuilder<List<BluetoothService>>(
                stream: device.services,
                initialData: [],
                builder: (c, snapshot) {
                  return Column(
                    children: _buildServiceTiles(snapshot.data),
                  );
                },
              ),
              (device.services != null ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                ButtonButton(
                  onPressed: () { print('pressed'); },
                  child: Container(
                  width: 300,
                  color: Colors.indigo.shade50,
                  child: TextField(
                    onChanged: (text) { _writeInput = text; },
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                        labelText: "Choose Service, then W",
                        border: OutlineInputBorder()),
                  ),

              ),
                ),
                  SizedBox(
                    width: 30,
                  ),
//                Builder(
//                  builder: (context) => ButtonButton(
//                    child: Text('CHECK'),
//                    onPressed: () {
//                      Scaffold.of(context).showSnackBar(SnackBar(
//                        content: Text('This is what you will write --- $_writeInput'),
//                        duration: Duration(seconds: 10),
//                      ));
//                    },
//                  ),
//                ),
                ],
              ) : (Text(' ')))
            ],
          ),
        ),
      ),
    );
  }
}
