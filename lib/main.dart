import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Mi App de Mapa',
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controlador para el mapa de Google
  GoogleMapController? _mapController;
  
  // Posición actual del usuario
  Position? _currentPosition;
  
  // Suscripción a los cambios de ubicación para poder cancelarla después
  StreamSubscription<Position>? _positionStreamSubscription;

  // Marcador dinámico que mostrará la ubicación del usuario
  Marker? _userMarker;

  @override
  void initState() {
    super.initState();
    _startListeningToLocation();
  }

  @override
  void dispose() {
    // Es MUY importante cancelar la suscripción para evitar fugas de memoria
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Función principal para obtener y escuchar la ubicación
  void _startListeningToLocation() async {
    // 1. Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Si no están habilitados, puedes mostrar un diálogo o un snackbar
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Los servicios de ubicación están deshabilitados.')));
      return;
    }

    // 2. Verificar los permisos de la aplicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Los permisos de ubicación fueron denegados.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Los permisos de ubicación están permanentemente denegados, no podemos solicitar permisos.')));
      return;
    }

    // 3. Si todo está bien, empezar a escuchar la ubicación
    // Usamos getPositionStream para recibir actualizaciones en tiempo real
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // Alta precisión
        distanceFilter: 10, // Notificar cambios cada 10 metros
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        // Cada vez que la posición cambia, actualizamos el marcador
        _userMarker = Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Mi Ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
      });
      // También movemos la cámara del mapa a la nueva posición
      _animateToUser();
    });
  }

  // Función para animar la cámara del mapa a la posición del usuario
  void _animateToUser() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 16.0,
          ),
        ),
      );
    }
  }
  
  // Posición inicial del mapa (por si la ubicación tarda en cargar)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962), // Un lugar por defecto
    zoom: 14.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa en Tiempo Real'),
        backgroundColor: Colors.teal,
      ),
      body: _currentPosition == null
          // Muestra un indicador de carga mientras se obtiene la primera ubicación
          ? const Center(child: CircularProgressIndicator())
          // Cuando ya tenemos la ubicación, muestra el mapa
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: _initialCameraPosition,
              mapType: MapType.normal,
              myLocationButtonEnabled: false, // Desactivamos el botón por defecto
              myLocationEnabled: false, // Desactivamos el punto azul por defecto
              markers: _userMarker != null ? {_userMarker!} : {}, // Añadimos nuestro marcador
            ),
      // Un botón flotante para centrar el mapa manualmente
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _animateToUser,
        label: const Text('Centrar'),
        icon: const Icon(Icons.location_on),
        backgroundColor: Colors.teal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}