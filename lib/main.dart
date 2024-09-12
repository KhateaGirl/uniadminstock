import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unistock/controllers/menu_controller.dart';
import 'package:unistock/controllers/navigation_controller.dart';
import 'package:unistock/widgets/log_in.dart';


class UserController extends GetxController {
  var documentId = ''.obs;  // Observable variable to store the document ID

  void setDocumentId(String id) {
    documentId.value = id;  // Update the document ID
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyD2aSmLHziXSvApGm8DSUGgLj0Wig8J4DI",
          projectId: "unistock-266e8",
          messagingSenderId: "735169171366",
          appId: "1:735169171366:web:9fabc735b0168d3fae0967"));

  Get.put(CustomMenuController());
  Get.put(NavigationController());
  Get.put(UserController());  // Initialize the UserController globally

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Admin Dashboard",
      theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
              .apply(bodyColor: Colors.black),
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()
          }),
          primaryColor: Colors.blue),
      home: LoginPage(),  // Starting page is the login page
    );
  }
}