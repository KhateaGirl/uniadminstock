import 'package:flutter/material.dart';
import 'package:unistock/pages/SettingsPage.dart';
import 'package:unistock/pages/authentication/authentication.dart';
import 'package:unistock/pages/inventory_stocks/inventory_stocks.dart';
import 'package:unistock/pages/overview/overview.dart';
import 'package:unistock/pages/reservation_list/reservation_list.dart';
import 'package:unistock/pages/sales_history/sales_history.dart';
import 'package:unistock/pages/sales_statistics/sales_statistics.dart';
import 'package:unistock/pages/walk-in/walk-in.dart';
import 'package:unistock/routing/routes.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case OverviewPageRoute:
      return _getPageRoute(OverviewPage());
    case InventoryPageRoute:
      return _getPageRoute(InventoryPage());
    case ReservationListPageRoute:
      return _getPageRoute(ReservationListPage());
    case SalesHistoryPageRoute:
      return _getPageRoute(SalesHistoryPage());
    case SalesStatisticsPageRoute:
      return _getPageRoute(SalesStatisticsPage());
    case WalkinPageRoute:
      return _getPageRoute(WalkinPage());
    case SettingsPageRoute:
      return _getPageRoute(SettingsPage());
    default:
      return _getPageRoute(AuthenticationPage());
  }
}

PageRoute _getPageRoute(Widget child) {
  return MaterialPageRoute(builder: (context) => child);
}