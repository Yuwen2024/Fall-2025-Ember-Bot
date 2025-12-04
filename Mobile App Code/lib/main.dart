import 'dart:convert';
import 'dart:math';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

/// Dropdown menu options for the AppBar leading menu
enum _MenuOption {
  copyright,
  contact,
  about,
}

void createRequest(
  int requestNumber,
  double left,
  double midX,
  double midY,
  double right,
  String ip,
  bool led,
  bool nozzle,
) {
  http
      .post(
    Uri.parse(ip),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'request_number': requestNumber,
      'LED_Control': (led ? 1.0 : 0.0),
      'left_position': left,
      'mid_x': midX,
      'mid_y': midY,
      'right_position': right,
      'pump': (nozzle ? 1.0 : 0.0),
    }),
  )
      .timeout(const Duration(milliseconds: 800))
      .catchError((error) {
    // Prevent errors from piling up.
    print('Request error: $error');
  });
}

class ServerResponse {
  final String time;
  final String response;

  const ServerResponse({required this.time, required this.response});

  factory ServerResponse.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'time': String time, 'response': String response} =>
        ServerResponse(time: time, response: response),
      _ => throw const FormatException('Failed to load response.'),
    };
  }
}

void main() {
  runApp(const EmberBotApp());
}

class EmberBotAppState extends ChangeNotifier {
  String requestUUID = '';
  int requestNumber = 0;
  var lastLeftPadel = 0.0;
  var leftPadel = 0.0;
  var lastRightPadel = 0.0;
  var rightPadel = 0.0;
  var nozzleVertical = 0.0;
  var nozzleHorizontal = 0.0;
  String responseText = 'Initial reading';
  String videoIP = '192.168.0.1';
  String serverIP = 'http://192.168.4.1/coords';
  String streamUrl = "http://192.168.4.50";
  bool LEDOn = false;
  bool pump = false;

  // 🔋 Battery level (%)
  double batteryPercent = 70.0;

  // 💧 Water level (%)
  double waterPercent = 80.0;

  void updateBattery(double newPercent) {
    batteryPercent = newPercent.clamp(0.0, 100.0);
    notifyListeners();
  }

  void updateWater(double newPercent) {
    waterPercent = newPercent.clamp(0.0, 100.0);
    notifyListeners();
  }

  void updateLED() {
    createRequest(
      requestNumber++,
      leftPadel,
      nozzleHorizontal,
      nozzleVertical,
      rightPadel,
      serverIP,
      LEDOn,
      pump,
    );
    notifyListeners();
  }

  void updateLeftTrack(var val) {
    leftPadel = 215.0 - val;

    if ((lastLeftPadel - leftPadel).abs() >= 5.0) {
      lastLeftPadel = leftPadel - (leftPadel % 5);
      createRequest(
        requestNumber++,
        leftPadel,
        nozzleHorizontal,
        nozzleVertical,
        rightPadel,
        serverIP,
        LEDOn,
        pump,
      );
      notifyListeners();
    }
  }

  void updateRightTrack(var val) {
    rightPadel = 215.0 - val;

    if ((lastRightPadel - rightPadel).abs() >= 5.0) {
      lastRightPadel = rightPadel - (rightPadel % 5);
      createRequest(
        requestNumber++,
        leftPadel,
        nozzleHorizontal,
        nozzleVertical,
        rightPadel,
        serverIP,
        LEDOn,
        pump,
      );
      notifyListeners();
    }
  }

  void updateNozzleAim(var x, var y) {
    nozzleHorizontal = (x - 225.0) / 15; // mapping to your ESP range
    nozzleVertical = (159.0 - y) / 26;
    createRequest(
      requestNumber++,
      leftPadel,
      nozzleHorizontal,
      nozzleVertical,
      rightPadel,
      serverIP,
      LEDOn,
      pump,
    );
    notifyListeners();
  }

  void updatePump() {
    createRequest(
      requestNumber++,
      leftPadel,
      nozzleHorizontal,
      nozzleVertical,
      rightPadel,
      serverIP,
      LEDOn,
      pump,
    );
    notifyListeners();
  }

  void updateServerIP(List<String> ip) {
    serverIP = ip[0];
    print("Server IP updated to $serverIP");
    streamUrl = ip[1];
    print("Video IP updated to $streamUrl");
    notifyListeners();
  }
}

class EmberBotApp extends StatelessWidget {
  const EmberBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EmberBotAppState(),
      child: MaterialApp(
        title: 'Ember Bot',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const MyHomePage(title: 'Ember Bot'),
      ),
    );
  }
}

class LeftMovementControlButton extends StatefulWidget {
  const LeftMovementControlButton({super.key});

  @override
  State<StatefulWidget> createState() => _LeftMovementControlButton();
}

class _LeftMovementControlButton extends State<LeftMovementControlButton> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<EmberBotAppState>();

    return Draggable(
      axis: Axis.vertical,
      feedback: SizedBox(
        height: 50.0,
        width: 50.0,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {},
            heroTag: UniqueKey(),
            child: const Icon(Icons.height),
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragUpdate: (details) {
        print("Left moving: ${details.globalPosition.dy.toStringAsFixed(2)}");
        appState.updateLeftTrack(details.globalPosition.dy);
      },
      onDraggableCanceled: (velocity, offset) {
        print("Left cancelled: 215.0");
        appState.updateLeftTrack(215.0);
      },
      child: SizedBox(
        height: 50.0,
        width: 50.0,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {
              print("Left button pressed");
            },
            heroTag: UniqueKey(),
            child: const Icon(Icons.height),
          ),
        ),
      ),
    );
  }
}

class RightMovementControlButton extends StatefulWidget {
  const RightMovementControlButton({super.key});

  @override
  State<StatefulWidget> createState() => _RightMovementControlButton();
}

class _RightMovementControlButton extends State<RightMovementControlButton> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<EmberBotAppState>();

    return Draggable(
      axis: Axis.vertical,
      feedback: SizedBox(
        height: 50.0,
        width: 50.0,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {},
            heroTag: UniqueKey(),
            child: const Icon(Icons.height),
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragUpdate: (details) {
        print("Right moving: ${details.globalPosition.dy.toStringAsFixed(2)}");
        appState.updateRightTrack(details.globalPosition.dy);
      },
      onDraggableCanceled: (velocity, offset) {
        print("Right cancelled: 215.0");
        appState.updateRightTrack(215.0);
      },
      child: SizedBox(
        height: 50.0,
        width: 50.0,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {
              print("Right button pressed");
            },
            heroTag: UniqueKey(),
            child: const Icon(Icons.height),
          ),
        ),
      ),
    );
  }
}

class NozzleMovementControlButton extends StatefulWidget {
  const NozzleMovementControlButton({
    super.key,
    required this.stackKey, // MUST be the key of the Stack where this is Positioned
  });

  final GlobalKey stackKey;

  @override
  State<NozzleMovementControlButton> createState() =>
      _NozzleMovementControlButtonState();
}

class _NozzleMovementControlButtonState
    extends State<NozzleMovementControlButton> {
  static const double _fabSize = 56.0;

  // Starting position inside the SAME Stack that owns widget.stackKey
  Offset _pos = const Offset(225, 159);

  RenderBox get _stackBox =>
      widget.stackKey.currentContext!.findRenderObject() as RenderBox;

  @override
  Widget build(BuildContext context) {
    final appState =
        context.read<EmberBotAppState>(); // use read to avoid rebuilds

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: PointerInterceptor(
        child: Draggable(
          feedback: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: _fabSize,
              height: _fabSize,
              child: FloatingActionButton(
                onPressed: null,
                heroTag: 'nozzle-feedback',
                child: const Icon(Icons.local_drink),
              ),
            ),
          ),
          childWhenDragging: const SizedBox(width: _fabSize, height: _fabSize),

          // We only update on release for now
          onDragUpdate: (details) {
            // If you want live updates, uncomment:
            // final local = _stackBox.globalToLocal(details.globalPosition);
            // appState.updateNozzleAim(local.dx, local.dy);
          },

          onDragEnd: (details) {
            final localTopLeft = _stackBox.globalToLocal(details.offset);

            final dx = min(max((localTopLeft.dx), 0.0), 450.0);
            final dy = min(max((localTopLeft.dy), 0.0), 318.0);

            setState(() => _pos = Offset(dx, dy));
            appState.updateNozzleAim(dx, dy);
          },

          child: SizedBox(
            width: _fabSize,
            height: _fabSize,
            child: FloatingActionButton(
              onPressed: () => debugPrint('Nozzle pressed'),
              heroTag: 'nozzle',
              child: const Icon(Icons.local_drink),
            ),
          ),
        ),
      ),
    );
  }
}

class WaterButton extends StatefulWidget {
  const WaterButton({super.key});

  @override
  State<StatefulWidget> createState() => _WaterButton();
}

class _WaterButton extends State<WaterButton> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<EmberBotAppState>();

    return FloatingActionButton(
      onPressed: () {
        setState(() {
          print("Water control button pressed");
          appState.pump = !appState.pump;
          appState.updatePump();
        });
      },
      child: Icon(appState.pump ? Icons.shower : Icons.sunny),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late final WebViewController _webview_controller;
  final GlobalKey _stackKey = GlobalKey();

  String ip = "192.168.4.1/coords";
  String streamUrl = "http://192.168.4.50";

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/butterfly.mp4");
    _controller.setLooping(true);
    _initializeVideoPlayerFuture = _controller.initialize();

    _webview_controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(streamUrl))
      ..enableZoom(false)
      ..setOverScrollMode(WebViewOverScrollMode.never)
      ..setVerticalScrollBarEnabled(false)
      ..setHorizontalScrollBarEnabled(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<EmberBotAppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        title: Text(widget.title),

        // 🔽 Pretty dropdown menu on top-left
        leading: PopupMenuButton<_MenuOption>(
          icon: const Icon(Icons.menu),
          tooltip: 'More',
          elevation: 8,
          offset: const Offset(0, kToolbarHeight),
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case _MenuOption.copyright:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CopyrightPage(),
                  ),
                );
                break;

              case _MenuOption.contact:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactPage(),
                  ),
                );
                break;

              case _MenuOption.about:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutPage(),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<_MenuOption>(
              value: _MenuOption.copyright,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.copyright,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  "Copyright",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "© 2025 EmberBot Team",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<_MenuOption>(
              value: _MenuOption.contact,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.email_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  "Contact Us",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Support & feedback",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<_MenuOption>(
              value: _MenuOption.about,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  "About EmberBot",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Project overview",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        actions: [
          // 🔋 Battery + 💧 Water indicators with warning colors
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Battery
                Icon(
                  appState.batteryPercent <= 15
                      ? Icons.battery_alert
                      : Icons.battery_full,
                  size: 20,
                  color: appState.batteryPercent <= 15
                      ? Colors.red
                      : appState.batteryPercent <= 40
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  '${appState.batteryPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(width: 12),

                // Water
                Icon(
                  Icons.water_drop,
                  size: 20,
                  color: appState.waterPercent <= 15
                      ? Colors.red
                      : appState.waterPercent <= 40
                          ? Colors.orange
                          : Colors.blueAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${appState.waterPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              print("Refresh button pressed");
              _webview_controller.loadRequest(Uri.parse(streamUrl));
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                appState.LEDOn = !appState.LEDOn;
                print("LED button pressed ${appState.LEDOn}");
                appState.updateLED();
              });
            },
            icon: appState.LEDOn
                ? const Icon(Icons.lightbulb)
                : const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            onPressed: () {
              print("Settings button pressed");
              _navigateAndDisplaySettings(appState, context);
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () {
              print("Build button pressed");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManualPage(),
                ),
              );
            },
            icon: const Icon(Icons.build),
          ),
        ],
      ),

      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              flex: 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(appState.leftPadel.toStringAsFixed(2)),
                  const SizedBox(height: 114),
                  const LeftMovementControlButton(),
                ],
              ),
            ),
            Expanded(
              flex: 38,
              child: Stack(
                key: _stackKey,
                children: [
                  Positioned.fill(
                    child: WebViewWidget(controller: _webview_controller),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "x = ${appState.nozzleHorizontal.toStringAsFixed(2)}, y = ${appState.nozzleVertical.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NozzleMovementControlButton(stackKey: _stackKey),
                ],
              ),
            ),
            Expanded(
              flex: 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(appState.rightPadel.toStringAsFixed(2)),
                  const SizedBox(height: 114),
                  const RightMovementControlButton(),
                  const SizedBox(height: 54),
                  const WaterButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateAndDisplaySettings(
      EmberBotAppState appState, BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserSettingPage()),
    );

    appState.updateServerIP(result);
    _webview_controller.loadRequest(Uri.parse(result[1]));
    print("Returned $result");
  }
}

class UserManualPage extends StatelessWidget {
  const UserManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Manual')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How to Use the EmberBot App",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 2-column layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ManualSection(
                        icon: Icons.wifi,
                        title: "1. Connect to EmberBot",
                        body:
                            "- Go to Wifi settings on your phone and connect to the network named Jonathan-ESP32.\n"
                            "- Turn on EmberBot using switch locate in the left side of EmberBot.\n"
                            "- Open the Ember Bot App and it is ready to go.\n"
                            "- Remeber to reconnect to the Jonathan Wifi everytime you restart the Ember Bot\n"
                            "- Open the Settings page from the gear icon to enter server IPs for your own devices.\n",
                      ),
                      SizedBox(height: 16),
                      _ManualSection(
                        icon: Icons.videocam,
                        title: "2. Camera View",
                        body:
                            "- The center panel shows the live video stream.\n"
                            "- The nozzle control button appears on top of the video.\n"
                            "- The green X/Y values indicate the current nozzle aim.",
                      ),
                      SizedBox(height: 16),
                      _ManualSection(
                        icon: Icons.height,
                        title: "3. Left/Right Track Control",
                        body:
                            "- Drag the left/right vertical buttons up or down.\n"
                            "- Movement is proportional to the drag distance.\n"
                            "- Use both paddles together to move forward or backward.\n",
                      ),
                      SizedBox(height: 16),

                      _ManualSection(
                        icon: Icons.refresh,
                        title: "4. Refresh Camera Connection",
                        body:
                            "- If the video feed freezes or disconnects, tap the Refresh button.\n"
                            "- This forces the app to reconnect to the EmberBot camera stream.\n"
                            "- Useful when Wi-Fi signal is weak or the ESP32 restarts.\n",
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // RIGHT COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ManualSection(
                        icon: Icons.local_drink,
                        title: "5. Nozzle Aiming",
                        body:
                            "- Drag the nozzle button across the video area.\n"
                            "- Horizontal movement changes X.\n"
                            "- Vertical movement changes Y.\n"
                            "- Releasing the button sends the updated aim.",
                      ),
                      SizedBox(height: 16),
                      _ManualSection(
                        icon: Icons.lightbulb_outline,
                        title: "6. LED Control",
                        body:
                            "- Tap the lightbulb icon on the top app bar.\n"
                            "- The icon lights up when the LED is ON.\n",
                      ),
                      SizedBox(height: 16),
                      _ManualSection(
                        icon: Icons.shower,
                        title: "7. Water Pump Control",
                        body:
                            "- Tap the shower icon button on the right column.\n"
                            "- When highlighted, the pump is active.\n"
                            "- Aim safely before using the pump.\n",
                      ),
                      SizedBox(height: 16),
                      _ManualSection(
                        icon: Icons.warning_amber_rounded,
                        title: "8. Safety Tips",
                        body:
                            "- Keep EmberBot away from people, pets, and electronics.\n"
                            "- Test in an open area before real use.\n"
                            "- Avoid spraying near power outlets.\n"
                            "- Always supervise the robot during operation.\n",
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small reusable widget for each manual section with icon + title + text.
class _ManualSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ManualSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UserSettingPage extends StatefulWidget {
  const UserSettingPage({super.key});

  @override
  State<UserSettingPage> createState() => _UserSettingPage();
}

class _UserSettingPage extends State<UserSettingPage> {
  final myController = TextEditingController(text: 'http://');
  final videoIPController = TextEditingController(text: 'http://');

  @override
  void dispose() {
    myController.dispose();
    videoIPController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("Settings"),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 35, vertical: 6),
              child: TextField(controller: myController),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 35, vertical: 6),
              child: TextField(controller: videoIPController),
            ),
            ElevatedButton(
              onPressed: () {
                print(myController.text);
                print(videoIPController.text);

                if (myController.text.isEmpty) {
                  myController.text = "http://";
                }

                if (videoIPController.text.isEmpty) {
                  videoIPController.text = "http://";
                }

                Navigator.pop(
                    context, [myController.text, videoIPController.text]);
              },
              child: const Text('Go back!'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple copyright page opened from the menu.
class CopyrightPage extends StatelessWidget {
  const CopyrightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Copyright")),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "© 2025 EmberBot Team\nAll rights reserved.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

/// Simple contact info page opened from the menu.
class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contact Us")),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "EmberBot Project Team\n\n"
            "Email: emberbot.help@gmail.com\n"
            "Phone: (352) 620-4577\n"
            "Location: Texas A&M University\n"
            "400 Bizzell St, College Station, TX 77843",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About EmberBot")),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "EmberBot Firefighting Robot",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "      EmberBot is designed and built as a firefighting robot intended for reducing the safety risks "
              "of firefighters in hard to reach areas.\n\n"
              "      This app provides a controller UI for operating EmberBot "
              "from a mobile device.",
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
