import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unistock/helpers/responsiveness.dart';
import 'package:unistock/routing/routes.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:unistock/widgets/log_in.dart';
import 'package:unistock/widgets/side_menu_item.dart';
import 'package:unistock/constants/controllers.dart';
import 'package:unistock/constants/style.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double _width = MediaQuery.of(context).size.width;

    return Container(
      color: light,
      child: ListView(
        children: [
          if (ResponsiveWidget.isSmallScreen(context))
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(width: _width / 48),
                    Padding(padding: EdgeInsets.only(right: 12),
                    ),
                    Flexible(child: CustomText(
                      text: "UNISTOCK",
                      size: 20,
                      weight: FontWeight.bold,
                      color: active,
                    )),
                    SizedBox(width: _width / 48)
                  ],
                ),
              ],
            ),
          Divider(color: lightGrey.withOpacity(.1),),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: sideMenuItems.map((itemName) => SideMenuItem(
              itemName: itemName == AuthenticationPageRoute ? "Log Out" : itemName,
              onTap: (){
                if(itemName == AuthenticationPageRoute){
                  Get.offAll(LoginPage());
                }

                if(!menuController.isActive(itemName)){
                  menuController.changeActiveitemTo(itemName);
                  if(ResponsiveWidget.isSmallScreen(context))
                  Get.back();
                  navigationController.navigateTo(itemName);
                }
              },
            )).toList(),
          )
        ],
      ),
    );
  }
}