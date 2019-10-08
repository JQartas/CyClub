//ICONS https://www.flaticon.com/authors/freepik
import 'package:cyclub/App.dart';
import 'package:cyclub/Profile.dart';
import 'package:cyclub/helpers/distance.dart';
import 'package:cyclub/helpers/polylines.dart';
import 'package:cyclub/pojos/User.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'package:cyclub/helpers/api.dart';
import 'package:http/http.dart' as http;
import 'package:cyclub/helpers/distance.dart';

class Map extends StatefulWidget {
  User user;
  Map(User user) {
    this.user = user;
  }
  @override
  _Map createState() => _Map(this.user);
}

class PersonalRoute {
  DateTime initTime;
  DateTime endTime;
  List<LatLng> coordinates;
  double totalDistance;

  PersonalRoute() {
    initTime = DateTime.now();
  }

  endRoute() {
    print("Route started  at " + initTime.toString());
    endTime = DateTime.now();
    print("Route ended at " + endTime.toString());
    this.getTotalDistance();
  }

  getTotalDistance() {
    var data = this.coordinates;
    double totalDistance = 0;
    for (var i = 0; i < data.length - 1; i++) {
      totalDistance += calculateDistance(data[i], data[i + 1]);
    }
    print("DISTANCIA TOTAL" + totalDistance.toString());
    this.totalDistance = totalDistance;
  }

  setCoordinates(coordinates) {
    print("EOOOO");
    print(coordinates);
    this.coordinates = coordinates;
  }
}

class _Map extends State<Map> {
  User user;
  _Map(User user) {
    this.user = user;
  }
  //Tracked route id for default
  static const TRACKED_ROUTE_ID = "89723457647654211242443";

  // Personal route object
  PersonalRoute myRoute = PersonalRoute();

  // Flag to know if the user's tracking its route
  bool _trackingMyRoute = false;
  int distance = 0;
  //Controller for Google Maps
  Completer<GoogleMapController> _controller = Completer();
  //Location object for this code
  Location location = new Location();
  //Marker for my position
  Marker myLocationMarker =
      Marker(markerId: MarkerId("me"), position: LatLng(0, 0));
  // Set of polylines that will be graphed in the map
  Set<Polyline> _graphedPolylines = Set();

  /**
   * initState will initialize the position of the app at user's
   * Also will get the routes from the api (TODO) and will save them to be traced in the map
   */
  @override
  initState() {
    super.initState();
    _createMarkerImageFromAsset("assets/bicycle5.png");
    _loadPolylines();
    _addLocationListener();
  }

  /**
   * This function will return an empty tracked route polyline with default ID
   */
  Polyline _getDefaultTrackingPolyline() {
    return Polyline(
        polylineId: PolylineId(TRACKED_ROUTE_ID),
        color: Colors.black,
        width: 5,
        visible: true,
        points: List<LatLng>());
  }

  void _updateMarker() {
    this.setState(() {
      myLocationMarker = Marker(
          markerId: MarkerId("MyLocationMarker"),
          position: LatLng(currentLocation.latitude, currentLocation.longitude),
          icon: bitmapImage);
    });
  }

  /**
   * Gets a list of polylines, and then sets it to the state
   */
  _loadPolylines() async {
    Set<Polyline> cityRoutes = await getRoutesPolylines();
    setState(() {
      _graphedPolylines.add(_getDefaultTrackingPolyline());
      _graphedPolylines.addAll(cityRoutes);
    });
  }

  _addLocationListener() {
    location.onLocationChanged().listen((location) {
      currentLocation = location;
      _updateMarker();
      _goToMyPos();
      this.setState(() {
        // Saving my tracked coordinates
        if (_trackingMyRoute) {
          LatLng coor = LatLng(location.latitude, location.longitude);
          _graphedPolylines
              .firstWhere(
                  (polyline) => polyline.polylineId.value == TRACKED_ROUTE_ID)
              .points
              .add(coor);
        }
      });
    });
  }

  /**
   * After map's created, this handler will be executed
   * first of all, we'll get position
   * then we'll point a marker right there, and we'll move the camera to that location
   * then we'll fill the polylines for the routes
   */
  _handleMapCreated(GoogleMapController controller) async {
    _controller.complete(controller);
    _getMyLocation();
  }

  _goToMyPos() {
    LatLng position =
        LatLng(currentLocation.latitude, currentLocation.longitude);
    goToPosition(position);
  }

  List<LatLng> getTrackedCoordinates() {
    return _graphedPolylines
        .firstWhere((polyline) => polyline.polylineId.value == TRACKED_ROUTE_ID)
        .points;
  }

  /**
   * This function will show:
   *  Coordinates of the route that user did
   *  Time that the user used in its route (TODO)
   * Also, it'll flip the tracking flag state, and it'll clean the user's route
   */
  _trackMyRouteButtonHandler() {
    if (_trackingMyRoute) {
      print(getTrackedCoordinates());
      myRoute.setCoordinates(_graphedPolylines
          .firstWhere(
              (polyline) => polyline.polylineId.value == TRACKED_ROUTE_ID)
          .points);
      myRoute.endRoute();
      myRoute = PersonalRoute();
    }
    // Update state to start/stop tracking routes
    this.setState(() {
      _trackingMyRoute = !_trackingMyRoute;
      restartTrackedPolyline();
    });
  }

  /**
   * This function will find the polyline of the tracked route and it'll restart its list of points
   */
  restartTrackedPolyline() {
    _graphedPolylines
        .firstWhere((polyline) => polyline.polylineId == TRACKED_ROUTE_ID)
        .points
        .removeWhere((point) => point != null);
  }

  @override
  Widget build(BuildContext context) {
    return _graphedPolylines.isEmpty
        ? Center(
            child: CircularProgressIndicator(),
          )
        : Stack(
            children: <Widget>[
              GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                      bearing: 0, target: LatLng(0, 0), tilt: 45, zoom: 16),
                  compassEnabled: false,
                  onMapCreated: _handleMapCreated,
                  myLocationEnabled: true,
                  markers: Set<Marker>.from([myLocationMarker]),
                  polylines: _graphedPolylines),
              MenuButton(this.user),
              AvatarButton(this.user),
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton(
                    iconSize: 50,
                    icon: Icon(Icons.trip_origin),
                    onPressed: _trackMyRouteButtonHandler),
              )
            ],
          );
  }

  /**
   * According to @target it'll make the map move right here
   */
  Future<void> goToPosition(LatLng target) async {
    var cameraTarget =
        CameraPosition(bearing: 0, target: target, tilt: 45, zoom: 16);

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraTarget));
    _updateMarker();
  }

  Future<BitmapDescriptor> _createMarkerImageFromAsset(String iconPath) async {
    ImageConfiguration configuration = ImageConfiguration();
    bitmapImage =
        await BitmapDescriptor.fromAssetImage(configuration, iconPath);
    return bitmapImage;
  }

  BitmapDescriptor bitmapImage;

  LocationData currentLocation;
  /**
   * It'll get my position and it'll call goToPosition() to move came to my position
   */
  Future<void> _getMyLocation() async {
    try {
      location.changeSettings(accuracy: LocationAccuracy.HIGH);
      currentLocation = await location.getLocation();
    } on PlatformException catch (e) {
      if (e.code == "PERMISSION DENIED") {
        print(e.code);
        location.requestPermission();
      }
    }
  }
}

class AvatarButton extends StatelessWidget {
  User user;
  AvatarButton(User user) {
    this.user = user;
  }
  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => Profile(
        this.user,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(0.0, 1.0);
        var end = Offset.zero;
        var curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  Widget build(context) {
    return Positioned(
      child: Stack(children: <Widget>[
        Positioned(
          bottom: -80,
          left: -60,
          child: Container(
            width: 225,
            height: 225,
            decoration: BoxDecoration(
              color: Colors.limeAccent
                  .withAlpha(0xBB), //I just wanted to say "Bebé" in Hex
              borderRadius: BorderRadius.all(Radius.circular(155)),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: -10,
          child: GestureDetector(
            onTap: () => Navigator.push(context, _createRoute()),
            child: Container(
              width: 167,
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  image: DecorationImage(
                      image: AssetImage("assets/Panita.png"),
                      fit: BoxFit.cover)),
            ),
          ),
        ),
      ]),
    );
  }
}

class MenuButton extends StatelessWidget {
  User user;
  MenuButton(User user) {
    this.user = user;
  }
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 0,
      child: IconButton(
          splashColor: Colors.grey,
          color: Colors.black,
          tooltip: 'Menu',
          iconSize: 50,
          icon: Icon(Icons.menu),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (BuildContext context) => SideBarMenu(user)))),
    );
  }
}
