//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/13/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import UIKit
import MapKit

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate {
    
    // MARK: Properties
    
    // Mapview center coordinates and zoom information.
    var mapCenterLatitude: Double?
    var mapCenterLongitude: Double?
    var mapSpanLatitudeDelta: Double?
    var mapSpanLongitudeDelta: Double?
    
    // MARK: IBOutlets
    
    // The map view.
    @IBOutlet weak var mapView: MKMapView!
    // Bottom tool bar with "delete pins" message
    @IBOutlet weak var deletePinsBottomToolbar: UIToolbar!
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Place edit button in navigation bar.
        self.navigationItem.rightBarButtonItem = self.editButtonItem

        // Display on the map all the pins the user has already dropped.
        for (key, _) in PinsAndPhotosDataStructure.locationsAndPhotos {
            mapView.addAnnotation(key)
        }
        
        // If this is not first time user is seeing this screen, each of the following
        // four keys will have had a Double value saved inside UserDefaults, reflecting
        // the mapview center coordinates and zoom level from most recent time user
        // saw this screen.
        mapCenterLatitude = UserDefaults.standard.double(forKey: "MapCenterLatitude")
        mapCenterLongitude = UserDefaults.standard.double(forKey: "MapCenterLongitude")
        mapSpanLatitudeDelta = UserDefaults.standard.double(forKey: "MapSpanLatitudeDelta")
        mapSpanLongitudeDelta = UserDefaults.standard.double(forKey: "MapSpanLongitudeDelta")
        
        // If mapview center coordinates and zoom level properties are not nil, set the
        // mapview's center coordinates and zoom level to whatever values they were when
        // the user last was on this screen.
        if let mapCenterLatitude = mapCenterLatitude, let mapCenterLongitude = mapCenterLongitude, let mapSpanLatitudeDelta = mapSpanLatitudeDelta, let mapSpanLongitudeDelta = mapSpanLongitudeDelta {
            let mapLocation = CLLocationCoordinate2D(latitude: mapCenterLatitude, longitude: mapCenterLongitude)
            let mapSpan = MKCoordinateSpanMake(mapSpanLatitudeDelta, mapSpanLongitudeDelta)
            
            let mapRegion = MKCoordinateRegionMake(mapLocation, mapSpan)
            mapView.setRegion(mapRegion, animated: false)
        }
    }
    
    // MARK: Edit button for deleting pins
    
    // Tapping "Edit" lets user delete any pin they tap.
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            // Reveal the bottom toolbar with "delete pins" message.
            UIView.animate(withDuration: 0.2, animations: {
                self.mapView.frame.origin.y -= self.deletePinsBottomToolbar.frame.height
            })
        } else {
            // Hide the bottom toolbar with "delete pins" message.
            UIView.animate(withDuration: 0.2, animations: {
                self.mapView.frame.origin.y += self.deletePinsBottomToolbar.frame.height
            })
        }
    }
    
    // MARK: Dropping a new pin
    
    // Drop a new pin on the map
    @IBAction func dropNewPin(gestureRecognizer: UILongPressGestureRecognizer) {
        // Prevents dropping multiple pins in one spot during a long-press.
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            let newPin = MKPointAnnotation()
            newPin.coordinate = newCoordinates
            
            // Display the pin on the map.
            mapView.addAnnotation(newPin)
            
            // Also sdd the new pin to the data structure, with an empty array for
            // the pin's coordinate's Flickr photos to be added to.
            PinsAndPhotosDataStructure.locationsAndPhotos[newPin] = []
        }
    }
}

extension TravelLocationsMapViewController {
    
    // MARK: MKMapViewDelegate
    
    // Define the style of the pins that appear on the map.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // Push the PhotoAlbumViewController when a pin is tapped. The controller will
    // display the Flickr photos associated with the pin.
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        // If user just tapped "Edit" button, selecting a pin deletes it
        // from the data structure and mapview.
        if isEditing {
            // Remove the pin from the data structure.
            PinsAndPhotosDataStructure.locationsAndPhotos.removeValue(forKey: view.annotation! as! MKPointAnnotation)
            
            // Remove pin from the map view.
            mapView.removeAnnotation(view.annotation!)

        } else {
            // Otherwise, selecting a pin takes us to its Flickr photo album:
            
            // Get the location Photo Album View Controller from the Storyboard
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
            
            // Update the pin property of the controller that will be pushed. (Tells the
            // controller which pin's photos should be displayed.)
            let pin = view.annotation as? MKPointAnnotation
            controller.pin = pin
            
            // Push the view controller.
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    // Store the center coordinates and zoom level of the region displayed in mapview, so
    // that these will persist and next time user returns to this screen, the mapview
    // will display the same region as it had the last time the user was at this screen.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        UserDefaults.standard.set(mapView.region.center.latitude, forKey: "MapCenterLatitude")
        UserDefaults.standard.set(mapView.region.center.longitude, forKey: "MapCenterLongitude")
        UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: "MapSpanLatitudeDelta")
        UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: "MapSpanLongitudeDelta")
    }
}

