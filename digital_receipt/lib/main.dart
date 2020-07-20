import 'package:device_preview/device_preview.dart';
import 'package:digital_receipt/models/customer.dart';
import 'package:digital_receipt/models/inventory.dart';
import 'package:digital_receipt/screens/home_page.dart';
import 'package:digital_receipt/screens/login_screen.dart';
import 'package:digital_receipt/screens/onboarding.dart';
import 'package:digital_receipt/screens/setup.dart';
import 'package:digital_receipt/services/api_service.dart';
import 'package:digital_receipt/services/hiveDb.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'utils/connected.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'models/notification.dart';
import './providers/business.dart';
import 'models/receipt.dart';
import 'services/sql_database_client.dart';
import 'services/shared_preference_service.dart';
import 'services/sql_database_repository.dart';
import 'package:path_provider/path_provider.dart';

//BACKGROUND MESSAGE HANDLER
Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) async {
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
    SqlDbClient sqlDbClient = SqlDbClient();
    SqlDbRepository _sqlDbRepository =
        SqlDbRepository(sqlDbClient: sqlDbClient);
    print(message['data']["click_action"]);
    //INSERTING NOTIFICATION TO SQFLITE DB
    NotificationModel notification = NotificationModel(
      id: message["data"]["id"],
      title: message['data']['title'],
      body: message['data']['body'],
      date: message["data"]["date"],
      isRead: message["data"]["isRead"],
    );
    await _sqlDbRepository.insertNotification(notification);
    //INSERTING NOTIFICATION TO SQFLITE DB
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    // final dynamic notification = message['notification'];
    // print(notification);

  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    // runApp(MyApp(),);
    runApp(DevicePreview(builder: (BuildContext context) => MyApp(), enabled: kReleaseMode,));

  } catch (e) {
    print("error occurd in main: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OverlaySupport(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => Business(),
          ),
          ChangeNotifierProvider(
            create: (context) => HiveDb(),
          ),
          ChangeNotifierProvider(
            create: (context) => Receipt(),
          ),
          ChangeNotifierProvider(
            create: (context) => Customer(),
          ),
          ChangeNotifierProvider(
            create: (context) => Inventory(),
          ),
          ChangeNotifierProvider(
            create: (context) => Connected(),
          ),
        ],
        child: MaterialApp(
          title: 'Degeit',
          theme: ThemeData(
            primaryColor: Color(0xFF0B57A7),
            scaffoldBackgroundColor: Color(0xFFF2F8FF),
            accentColor: Color(0xFF25CCB3),
            
            textTheme: TextTheme(
              bodyText1: TextStyle(
                fontFamily: 'Montserrat',
              ),
              bodyText2: TextStyle(
                fontFamily: 'Montserrat',
              ),
              button: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
          home: HomePage(),
        ),
      ),
    );
  }
}

class ScreenController extends StatefulWidget {
  @override
  _ScreenControllerState createState() => _ScreenControllerState();
}

class _ScreenControllerState extends State<ScreenController> {
  final SharedPreferenceService _sharedPreferenceService =
      SharedPreferenceService();
  static SqlDbClient sqlDbClient = SqlDbClient();
  SqlDbRepository _sqlDbRepository = SqlDbRepository(sqlDbClient: sqlDbClient);
  ApiService _apiService = ApiService();

  //Initializing SQL Database.
  initSharedPreferenceDb() async {
    await _sqlDbRepository.createDatabase();
  }

  bool _currentAutoLogoutStatus;

  getCurrentAutoLogoutStatus() async {
    _currentAutoLogoutStatus =
        await _sharedPreferenceService.getBoolValuesSF("AUTO_LOGOUT") ?? false;
    if (_currentAutoLogoutStatus) {
      String token =
          await _sharedPreferenceService.getStringValuesSF('AUTH_TOKEN');
      // print('token: $token');
      if (token != null) {
        var res = await _apiService.logOutUser(token);
        print(res);
        if (res == true) {
          return LogInScreen();
        }
      }
    }
  }

  initConnect() async {
    Provider.of<Connected>(context, listen: false).init();
    Provider.of<Connected>(context, listen: false).stream.listen((event) {
      print(event);
    });
  }

  @override
  void initState() {
    super.initState();
    // initConnect();

    initSharedPreferenceDb();
    getCurrentAutoLogoutStatus();

    final FirebaseMessaging _fcm = FirebaseMessaging();

    if (Platform.isIOS) {
      _fcm.requestNotificationPermissions(IosNotificationSettings());
    }

    _fcm.configure(
      
      onMessage: (Map<String, dynamic> message) async {
        print(message["data"]["id"]);
        print(message["notification"]["id"]);
        print("onMessage: $message");
        showOverlayNotification((context) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: SafeArea(
              child: ListTile(
                leading: SizedBox.fromSize(
                    size: const Size(40, 40),
                    child: ClipOval(
                        child: Container(
                      color: Colors.black,
                    ))),
                title: Text('${message['notification']['title']}'),
                subtitle: Text('${message['notification']['body']}'),
                trailing: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      OverlaySupportEntry.of(context).dismiss();
                    }),
              ),
            ),
          );
        }, duration: Duration(hours: 1));

        //INSERTING NOTIFICATION TO SQFLITE DB
        NotificationModel notification = NotificationModel(
          id: message["data"]["id"],
          title: message['notification']['title'],
          body: message['notification']['body'],
          date: message["data"]["date"],
          isRead: message["data"]["isRead"],
        );
        await _sqlDbRepository.insertNotification(notification);
        //INSERTING NOTIFICATION TO SQFLITE DB
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");

        //INSERTING NOTIFICATION TO SQFLITE DB
        NotificationModel notification = NotificationModel(
          id: message["data"]["id"],
          title: message['notification']['title'],
          body: message['notification']['body'],
          date: message["data"]["date"],
          isRead: message["data"]["isRead"],
        );
        await _sqlDbRepository.insertNotification(notification);
        //INSERTING NOTIFICATION TO SQFLITE DB
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");

        //INSERTING NOTIFICATION TO SQFLITE DB
        NotificationModel notification = NotificationModel(
          id: message["data"]["id"],
          title: message['notification']['title'],
          body: message['notification']['body'],
          date: message["data"]["date"],
          isRead: message["data"]["isRead"],
        );
        await _sqlDbRepository.insertNotification(notification);
        //INSERTING NOTIFICATION TO SQFLITE DB
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Future.wait([
          _sharedPreferenceService.getStringValuesSF("AUTH_TOKEN"),
          _sharedPreferenceService.getStringValuesSF("BUSINESS_INFO")
        ]),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          // await _pushNotificationService.initialise();
           print('snapshots: ${snapshot.data}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            );
            // TODO Reverse if-condition to show OnBoarding

          } else if (snapshot.data[0] == 'empty' || _currentAutoLogoutStatus) {
            return LogInScreen();
          } else if (snapshot.hasData &&
              snapshot.data[0] != null &&
              snapshot.data[1] != null) {
            return HomePage();
          } else if (snapshot.data[0] != null && snapshot.data[1] == null) {
            return Setup();
          } else {
            return OnboardingPage();
          }
        });
  }
}
