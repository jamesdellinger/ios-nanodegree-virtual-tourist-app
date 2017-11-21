//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/13/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    // MARK: Shared managed object context
 
    var sharedContext = CoreDataStack.sharedInstance().managedObjectContext
    
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
        
        // Fetch any pins user has already saved:
        // First create the fetched results controller to retrieve all pins currently
        // stored in core data.
        if let pinFetchedResultsController = createPinFetchedResultsController(nil, nil) {
            
            // Then perform the fetch request to retrieve those pins.
            performPinFetchRequest(pinFetchedResultsController)
            
            // Retrieve the latitude and longitude of each Pin stored in core data
            // and convert to a corresponding MKPointAnnotation object.
            if let pins = pinFetchedResultsController.fetchedObjects {
                for pin in pins {
                    let pinMKPointAnnotation = MKPointAnnotation()
                    pinMKPointAnnotation.coordinate.latitude = pin.latitude
                    pinMKPointAnnotation.coordinate.longitude = pin.longitude
                    // Display the MKPointAnnotation (the pin) in the map view.
                    mapView.addAnnotation(pinMKPointAnnotation)
                }
            }
        }
    }
    
    // MARK: Pin fetch request controller
    
    // Build the fetch request controller that will be used to fetch pins.
    // If called with parameters for latitude and longitude of a specific pin,
    // fetches performed with the controller this method returns will return
    // just that one pin. Otherwise, fetches performed with the controller returned
    // by this method will return all pins that have been stored in core data.
    func createPinFetchedResultsController(_ pinLatitude: Double?, _ pinLongitude: Double?) -> NSFetchedResultsController<Pin>? {
        
        let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
        fetchRequest.sortDescriptors = []

        if let latitude = pinLatitude, let longitude = pinLongitude {
            let predicate = NSPredicate(format: "latitude = %@ && longitude = %@", argumentArray: [latitude, longitude])
            fetchRequest.predicate = predicate
        }
        
        let pinFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        pinFetchedResultsController.delegate = self
        
        return pinFetchedResultsController
    }
    
    // MARK: Perform pin fetch request
    
    // Make the pin fetch request, taking as a parameter a the fetched results controller created
    // by the createPinFetchedResultsController() method.
    func performPinFetchRequest(_ pinFetchedResultsController: NSFetchedResultsController<Pin>?) {
        
        if let pinFetchedResultsController = pinFetchedResultsController {
            var error: NSError?
            do {
                try pinFetchedResultsController.performFetch()
            } catch let pinFetchError as NSError {
                error = pinFetchError
            }
            
            if let error = error {
                print("Error performing initial fetch: \(error)")
            }
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
            
            // Add the just-dropped pin to core data.
            let pin = Pin(context: sharedContext)
            // Ensure that the newly stored pin's latitude and longitude are
            // the same as what the user just droppped.
            pin.latitude = newCoordinates.latitude
            pin.longitude = newCoordinates.longitude
            // Save the context after storing the new pin in core data.
            CoreDataStack.sharedInstance().saveContext()
        }
    }
    
    // MARK: Deleting a pin
    
    // Delete a pin from the map view and from core data.
    func deletePin(selectedPinView: MKAnnotationView) {
        
        // Find the pin in core data.
        if let correspondingPinInCoreData = matchPinOnMapWithPinInCoreData(selectedPinView: selectedPinView) {
            // And if it exists, delete it from core data.
            sharedContext.delete(correspondingPinInCoreData)
            
            // Save the context after deleting the pin from core data.
            CoreDataStack.sharedInstance().saveContext()
            print("Pin Deleted!")
            
            // Also remove the pin from the map view.
            mapView.removeAnnotation(selectedPinView.annotation!)
        }
    }
    
    // MARK: Matching a pin on the map with pin stored in core data
    
    // When a user taps a pin on the map, we need to locate and return the
    // corresponding pin that's stored in core data.
    func matchPinOnMapWithPinInCoreData(selectedPinView: MKAnnotationView) -> Pin? {
        
        // Create the fetched results controller, passing parameters for latitude and longitude of the
        // pin on the map that the user tapped, in order to fetch the corresponding pin stored in core data.
        if let pinFetchedResultsController = createPinFetchedResultsController(selectedPinView.annotation?.coordinate.latitude, selectedPinView.annotation?.coordinate.longitude) {
            
            // Perform fetch using the fetched results controller we just configured above.
            performPinFetchRequest(pinFetchedResultsController)
            
            // Make sure there was at least one pin from core data that matches the one
            // that the user tapped.
            if let matchingPins = pinFetchedResultsController.fetchedObjects, matchingPins.count > 0 {
                
                // And if so, return this pin
                let correspondingPinInCoreData = matchingPins.first!
                return correspondingPinInCoreData
            }
            // Otherwise, return nil.
            return nil
        }
        else {
            return nil
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
    
    // Pushes the PhotoAlbumViewController, or deletes a pin, when a pin is tapped.
    // The controller will display the Flickr photos associated with the pin.
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        if isEditing {
            // If user just tapped "Edit" button, selecting a pin deletes it
            // from the data structure and mapview.
            deletePin(selectedPinView: view)
            
        } else {
            // Otherwise, selecting a pin takes the user to its Flickr photo album:
            
            // Get the location Photo Album View Controller from the Storyboard
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
            
            // Find the pin in core data.
            if let correspondingPinInCoreData = matchPinOnMapWithPinInCoreData(selectedPinView: view) {
                
                // And if it exists, send this pin to the view controller that will be pushed.
                controller.selectedPin = correspondingPinInCoreData
                print("Selected PIN: \(correspondingPinInCoreData) END")
                
                // Push the view controller.
                self.navigationController?.pushViewController(controller, animated: true)
            }
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

