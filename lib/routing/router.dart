import 'package:flutter/material.dart';
import 'package:unistock/pages/AboutUs.dart';
import 'package:unistock/pages/SettingsPage.dart';
import 'package:unistock/pages/authentication/authentication.dart';
import 'package:unistock/pages/inventory_stocks/inventory_stocks.dart';
import 'package:unistock/pages/overview/overview.dart';
import 'package:unistock/pages/reservation_list/reservation_list.dart';
import 'package:unistock/pages/sales_history/sales_history.dart';
import 'package:unistock/pages/sales_statistics/sales_statistics.dart';
import 'package:unistock/pages/walk-in/walk-in.dart';
import 'package:unistock/routing/routes.dart';

// Route settings to generate routes
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
    case AboutUsPageRoute: // Added this case for AboutUsPage
      return _getPageRoute(AboutUsPage()); // Use AboutUsPage here
    default:
      return _getPageRoute(AuthenticationPage());
  }
}

// Helper function to create a MaterialPageRoute
PageRoute _getPageRoute(Widget child) {
  return MaterialPageRoute(builder: (context) => child);
}
