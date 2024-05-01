import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location locationController = Location();
  static const LatLng collegeLocation = LatLng(9.726698, 76.726193);
  LatLng? currentPosition;
  List<LatLng> polylineCoordinates = [];
  GoogleMapController? mapController;
  String? distanceText = '';

  @override
  void initState() {
    super.initState();
    _getLocationUpdate();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: collegeLocation,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId("college"),
                icon: BitmapDescriptor.defaultMarker,
                position: collegeLocation,
              ),
              if (currentPosition != null)
                Marker(
                  markerId: const MarkerId("currentLocation"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  position: currentPosition!,
                ),
            },
            polylines: {
              if (polylineCoordinates.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId("directions"),
                  points: polylineCoordinates,
                  color: Colors.blue,
                  width: 5,
                  geodesic: true, // Improve polyline accuracy
                ),
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Distance: $distanceText',
                style: TextStyle(
                  color: Colors.green[700], // Olive green color
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              _createBounds(collegeLocation, currentPosition!),
              100,
            ),
          );
        },
        child: const Icon(Icons.zoom_out_map),
      ),
    );
  }

  Future<void> _getLocationUpdate() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await locationController.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await locationController.requestService();
    }

    _permissionGranted = await locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await locationController.requestPermission();
    }

    if (_permissionGranted == PermissionStatus.granted) {
      locationController.onLocationChanged
          .listen((LocationData currentLocation) {
        if (currentLocation.latitude != null &&
            currentLocation.longitude != null) {
          setState(() {
            currentPosition =
                LatLng(currentLocation.latitude!, currentLocation.longitude!);
            _getPolyline();
          });
        }
      });
    }
  }

  Future<void> _getPolyline() async {
    if (currentPosition == null) return; // Ensure currentPosition is not null
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${currentPosition!.latitude},${currentPosition!.longitude}&destination=${collegeLocation.latitude},${collegeLocation.longitude}&key=AIzaSyDyUDNLsdECIrWJLGW980zwr5YrgZoSOko";
    http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Map data = jsonDecode(response.body);
      if (data["status"] == "OK") {
        List steps = data["routes"][0]["legs"][0]["steps"];
        distanceText = data["routes"][0]["legs"][0]["distance"]["text"];

        polylineCoordinates.clear();
        for (var step in steps) {
          List<LatLng> points = _decodePolyline(step["polyline"]["points"]);
          polylineCoordinates.addAll(points);
        }

        setState(() {
          // Update the polyline to show the new route
        });
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      poly.add(LatLng(latitude, longitude));
    }
    return poly;
  }

  LatLngBounds _createBounds(LatLng southwest, LatLng northeast) {
    return LatLngBounds(
      southwest: LatLng(
        southwest.latitude <= northeast.latitude
            ? southwest.latitude
            : northeast.latitude,
        southwest.longitude <= northeast.longitude
            ? southwest.longitude
            : northeast.longitude,
      ),
      northeast: LatLng(
        southwest.latitude > northeast.latitude
            ? southwest.latitude
            : northeast.latitude,
        southwest.longitude > northeast.longitude
            ? southwest.longitude
            : northeast.longitude,
      ),
    );
  }
}
