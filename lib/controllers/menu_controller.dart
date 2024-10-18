import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unistock/constants/style.dart';
import 'package:unistock/routing/routes.dart';

class CustomMenuController extends GetxController{
  static CustomMenuController instance = Get.find();
  var activeItem = OverviewPageRoute.obs;
  var hoverItem = "".obs;

  changeActiveitemTo(String itemName){
    activeItem.value = itemName;
  } 

  onHover(String itemName){
    if(!isActive(itemName)) hoverItem.value = itemName;
  }

  isActive(String itemName) => activeItem.value == itemName;

  isHovering(String itemName) => hoverItem.value == itemName;

  Widget returnIconfor(String itemName){
    switch (itemName){
      case OverviewPageRoute:
        return _customIcon(Icons.dashboard, itemName);
      case InventoryPageRoute:
        return _customIcon(Icons.inventory_sharp, itemName);
      case ReservationListPageRoute:
        return _customIcon(Icons.checklist, itemName);
      case SalesHistoryPageRoute:
        return _customIcon(Icons.history, itemName);
      case SalesStatisticsPageRoute:
        return _customIcon(Icons.insights, itemName);
      case WalkinPageRoute:
        return _customIcon(Icons.directions_walk, itemName);
      case AuthenticationPageRoute:
        return _customIcon(Icons.exit_to_app, itemName);
      case AboutUsPageRoute:
        return _customIcon(Icons.people_alt, itemName);
        default:
        return _customIcon(Icons.exit_to_app, itemName);
    }
  }

  Widget _customIcon(IconData icon, String itemName){
    if(isActive(itemName)) return Icon(icon, size: 22, color: active,);

    return Icon(icon, color: isHovering(itemName) ? active : dark,);
  }
}