class ApiRouteConstants {
  //? Auth module
  static const String authregisterRoute = '/api/auth/register';
  static const String authCreateRegisterRoute = '/api/auth/createuser';
  static const String authResetRoute = '/api/auth/reset';
  static const String authDeleteRoute = '/api/auth/delete';
  static const String authloginRoute = '/api/auth/login';
  static const String authUserRoute = '/api/auth/users';
  static const String authDivisionsRoute = '/api/auth/divisions';

  //? Store module

  static const String storeItemRoute = '/api/store/items';
  static const String storeItemScrapRoute = '/api/store/scrap';
  static const String storeItemsDeleteRoute = '/api/store/itemsdelete';

  static const String storePlaceRoute = '/api/store/place';
  static const String storePlacesDeleteRoute = '/api/store/placedelete';

  static const String itemReceiveRoute = '/api/store/receive';
  static const String itemReceivesDeleteRoute = '/api/store/receivedelete';
  static const String itemReceivesApproveRoute = '/api/store/receiveapprove';
  static const String itemReceivesRejectRoute = '/api/store/receivereject';
  static const String itemReceivesToPlaceRoute = '/api/store/receivetoplace';
  static const String itemReceivesCloseRoute = '/api/store/receiveclose';
  static const String itemPlaceReceivesCloseRoute = '/api/store/places';

  static const String itemIssueRoute = '/api/store/issue';
  static const String itemIssuesDeleteRoute = '/api/store/issuedelete';
  static const String itemIssuesApproveRoute = '/api/store/issueapprove';
  static const String itemIssuesRejectRoute = '/api/store/issuereject';
  static const String itemIssuesToPlaceRoute = '/api/store/issuetoplace';
  static const String returnItemIssueRoute = '/api/store/returnitemissue';
  static const String closeItemIssueRoute = '/api/store/closeitemissue';

  // in ApiRouteConstants
  static const String bagRoute = '/api/bags';
  static const String itemRoute = '/api/items';
  static const String sizeRoute = '/api/sizes';
  static const String gradeRoute = '/api/grades';

  static const String sortingJobsRoute = '/sorting-jobs';
  static const String sortingJobStartRoute =
      '/sorting-jobs/start'; // or '/sorting-jobs/:id/start'
  static const String sortingJobStopRoute = '/sorting-jobs/stop';
  static const String sortingJobRestartRoute = '/sorting-jobs/restart';

  static const String storeRoomsRoute = "/api/rooms";

  static const String storeRackRoomsRoute = "/api/rackrooms";

  static const String storeRacksRoute = "/api/racks";
}
