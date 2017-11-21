//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/14/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    // MARK: Photo Fetched Results Controller
    
    lazy var photoFetchedResultsController: NSFetchedResultsController<Photo> = { () -> NSFetchedResultsController<Photo> in
        
        let photoFetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        photoFetchRequest.sortDescriptors = []
        
        if let pin = selectedPin {
            let predicate = NSPredicate(format: "pin == %@", pin)
            photoFetchRequest.predicate = predicate
        }
        
        let photoFetchedResultsController = NSFetchedResultsController(fetchRequest: photoFetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        photoFetchedResultsController.delegate = self
        
        return photoFetchedResultsController
    }()
    
    // MARK: Shared managed object context
    
    var sharedContext = CoreDataStack.sharedInstance().managedObjectContext
    
    // MARK: Properties
    
    // The pin that the user selected.
    var selectedPin: Pin?
    // Index paths of collection cells that the user has selected
    var selectedCellIndexPaths: [IndexPath] = []
    // Number of cells to be displayed in the collectiom boew
    var numberOfItemsInSection: Int = 0
    // An array of photos URLs associated with the pin.
    var pinPhotoURLs: [String]?
    
    // MARK: IBOutlets
    
    // Collection view
    @IBOutlet weak var collectionView: UICollectionView!
    // Collection View Flow Layout outlet
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    // Map view outlet
    @IBOutlet weak var pinMapView: MKMapView!
    // "New Collection" button outlet
    @IBOutlet weak var newCollectionBarButton: UIBarButtonItem!
    // Status label that displays message if no images can be found or downloaded.
    @IBOutlet weak var statusLabel: UILabel!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display the pin on the map view inside this controller.
        displayPinInMapView(pin: selectedPin!)
        
        // Get collection flow layout collection view controller first loads
        if UIDevice.current.orientation.isPortrait {
            setCollectionFlowLayout("Portrait")
        } else {
            setCollectionFlowLayout("Landscape")
        }
        
        // The collection view must allow multiple cells to be selected.
        collectionView.allowsMultipleSelection = true
        
        // Fetch the pin's photos from core data.
        var photoFetchError: NSError?
        do {
            try photoFetchedResultsController.performFetch()
        } catch let error as NSError {
            photoFetchError = error
        }
        
        if let photoFetchError = photoFetchError {
            print("Error performing photo fetch: \(photoFetchError)")
        }
        
        // If the pin doesn't already have any photos saved in core data, or download a
        // new set of photos for the pin so they can be displayed in the collection view.
        if let fetchedPhotosForPin = photoFetchedResultsController.fetchedObjects, fetchedPhotosForPin.count == 0 {
            downloadPinPhotos(selectedPin!)
        }
    }
    
    // Update collection flow layout if device orientation changes while
    // collection view is still visible.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Use a closure so that current orientation is detected only
        // after orientation has completed its change
        coordinator.animate(alongsideTransition: nil) { _ in
            if UIDevice.current.orientation.isPortrait {
                self.setCollectionFlowLayout("Portrait")
            } else {
                self.setCollectionFlowLayout("Landscape")
            }
        }
    }
    
    // MARK: Reload all photos or delete selected photos
    @IBAction func reloadOrDeletePhotos(_ sender: Any) {
        
        // If title of bottom button is "New Collection" we know that no collection
        // view cells have been selected and so tapping this button should load and store
        // a fresh set of photos from Flickr for the pin.
        if newCollectionBarButton.title == "New Collection" {
            // Clear the photos stored in the data structure.
            if let storedPhotos = photoFetchedResultsController.fetchedObjects {
                for photo in storedPhotos {
                    sharedContext.delete(photo)
                }
            }
            performUIUpdatesOnMain {
                // Save the context after deleting all of the pin's photos from core data.
                CoreDataStack.sharedInstance().saveContext()
            }
            
            // Download a new set of photos for the pin.
            downloadPinPhotos(selectedPin!)
        }
        
        // If title of bottom button is "Remove Selected Photos" we know that
        // at least one collection view cell has been selected, and function of
        // tapping this button should be deleting selected cells.
        if newCollectionBarButton.title == "Remove Selected Photos" {
            
            // Perform a batch update to display any and all cell deletion animations simultaneously.
            collectionView.performBatchUpdates({
                // Delete all corresponding photos from the data structure
                for indexPath in selectedCellIndexPaths {
                    if let photos = photoFetchedResultsController.fetchedObjects {
                        sharedContext.delete(photos[(indexPath as NSIndexPath).item])
                        performUIUpdatesOnMain {
                            // Save the context after deleting a photo from core data.
                            CoreDataStack.sharedInstance().saveContext()
                        }
                    }
                }
                
                // Delete all selected cells from the collection view
                collectionView.deleteItems(at: selectedCellIndexPaths)
            })
        }
        
        // Reset array that tracks selected cells now that all selected cells have been deleted.
        selectedCellIndexPaths = []
        // Also change title of bar button back to "New Collection"
        newCollectionBarButton.title = "New Collection"
    }
    
    // MARK: Display pin inside the map view.
    
    func displayPinInMapView(pin: Pin) {
        
        // Get the pin's CLLocation so that pin's coordinates can be reverse geocoded.
        let pinLatitude = pin.latitude
        let pinLongitude = pin.longitude
        let pinLocation = CLLocation(latitude: pinLatitude, longitude: pinLongitude)
        
        // Convert the pin object to MKAnnotation object so that it can be
        // displayed within this view controller's map view.
        let pinAnnotation = MKPointAnnotation()
        pinAnnotation.coordinate.latitude = pinLatitude
        pinAnnotation.coordinate.longitude = pinLongitude
        
        // Reverse geocode the coordinates of the pin so that the resulting address string can
        // be displayed as the title of the map pin annotation if/when user taps on the pin.
        reverseGeoCode(pinLocation) { (locationAddress) in
            
            // Set the title of the annotation to the address that was
            // reverse geo coded. (Returns "No Matching Addresses Found" if
            // reverse geocode lookup was unsuccessful.)
            pinAnnotation.title = locationAddress
            
            // Add the pin annotation to the map.
            self.pinMapView.addAnnotation(pinAnnotation)
            
            // Make sure the map is centered on this one annotation.
            self.pinMapView.centerCoordinate = pinAnnotation.coordinate
            
            // And make sure the map is zoomed in fairly close in to the pin.
            self.pinMapView.camera.altitude = 1000.0
        }
    }
    
    // MARK: Load a new set of images for a pin
    
    func downloadPinPhotos(_ pin: Pin) {
        // Get an array of Flickr URL strings for Flickr photos taken at or near
        // the geographic coordinates of the selected pin.
        let latitude = pin.latitude
        let longitude = pin.longitude
        
        // Get a fresh set of URLs for Flickr photos taken in the vicinity of the
        // pin's geographic coordinates.
        FlickrClient.sharedInstance().getFlickrPhotosURLArrayForPin(latitude, longitude) { (flickrPhotosURLArrayForPin, success, errorString) in
            performUIUpdatesOnMain {
                if success {
                    // If successful, set the pinPhotoURLs property to the array of URLs returned in
                    // the completion handler.
                    self.pinPhotoURLs = flickrPhotosURLArrayForPin!
                    // Images will be displayed so no need to display a error message.
                    self.statusLabel.isHidden = true
                    // Reload the collection view, which will now download images from the
                    // URLs just received, which are now contained in the pinPhotoURLs variable.
                    self.collectionView.reloadData()
                } else {
                    // If no URLs could be retrieved, then no cells will be displayed, so the
                    // error message will be displayed in the center of the collection view.
                    self.statusLabel.isHidden = false
                    self.statusLabel.text = errorString!
                }
            }
        }
    }
    
    // MARK: Long-pressing a photo to view large size
    
    @IBAction func displayLargePhotoOnLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state == .began {
            
            let pointOfLongPress = gestureRecognizer.location(in: collectionView)
            
            let indexPathCorrespondingToPressPoint = collectionView.indexPathForItem(at: pointOfLongPress)
            
            if let indexPath = indexPathCorrespondingToPressPoint {
                
                // Get the location Photo Detail View Controller from the Storyboard
                let controller = self.storyboard!.instantiateViewController(withIdentifier: "PhotoDetailViewController") as! PhotoDetailViewController
                
                // Update the photo which will be displayed in Photo Detail controller to that
                // which corresponds to the collection cell which the user has long pressed on.
                if let storedPhotoForCell = photoFetchedResultsController.fetchedObjects?[(indexPath as NSIndexPath).item] {
                    controller.photo = UIImage(data: storedPhotoForCell.imageData! as Data)
                }
                
                // Push the view controller.
                self.navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
}

// MARK: UICollectionViewDelegate

extension PhotoAlbumViewController {
    
    // MARK: Defining the collection view flow layout
    
    // Call this function from viewDidLoad to get initial flow layout for
    // collection. Also called from closure of viewWillTransition() method to
    // get an updated flow layout when orientation changes from portrait to landscape,
    // or vice-versa.
    func setCollectionFlowLayout(_ currentDeviceOrientation: String) {
        
        let space: CGFloat = 3.0
        
        var dimension: CGFloat { get {
            if currentDeviceOrientation == "Portrait" {
                // Keeps column spacing uniform if device is in portrait orientation
                return (view.frame.size.width - (2 * space)) / 3.0
            } else  {
                // Keeps column spacing uniform if device is in landscape orientation
                return (view.frame.size.width - (4 * space)) / 5.0
            }}
        }
        
        flowLayout?.minimumInteritemSpacing = space
        flowLayout?.minimumLineSpacing = space
        flowLayout?.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    // MARK: Return the number of cells
    
    // Get the number of cells (photos) that will appear in the collection view
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        // The number of Flickr photos that are available for the pin, which is the number
        // of cells that will be displayed inside this collection view:
        if let fetchedPhotos = photoFetchedResultsController.fetchedObjects, fetchedPhotos.count > 0 {
            numberOfItemsInSection = fetchedPhotos.count
        }
        else if let pinPhotoURLs = pinPhotoURLs {
            numberOfItemsInSection = pinPhotoURLs.count
        } else {
            numberOfItemsInSection = 0
        }
        print(numberOfItemsInSection)
        return numberOfItemsInSection
    }
    
    // MARK: Display cells
    
    // Dequeue cells as they are displayed in the meme collection view controller
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // The cell to be dequeued
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        // Fetch the pin's photos from core data.
        var photoFetchError: NSError?
        do {
            try photoFetchedResultsController.performFetch()
        } catch let error as NSError {
            photoFetchError = error
        }
        
        if let photoFetchError = photoFetchError {
            print("Error performing photo fetch: \(photoFetchError)")
        }
        
        
        if let fetchedPhotos = photoFetchedResultsController.fetchedObjects, fetchedPhotos.count > 0, fetchedPhotos.count > (indexPath as NSIndexPath).item {

            let storedPhotoForCell = fetchedPhotos[(indexPath as NSIndexPath).item]
            cell.collectionCellImageView?.image = UIImage(data: storedPhotoForCell.imageData! as Data)
        } else {
            // If no photo has been stored, then get the URL of the photo that corresponds to the item
            // index of the cell.
            let photoURL = pinPhotoURLs![(indexPath as NSIndexPath).item]
            
            // Display the placeholder image in the cell, which will remain visible until the photo
            // that exists at the URL is loaded.
            cell.collectionCellImageView?.image = #imageLiteral(resourceName: "default-placeholder")
            
            // Also begin animating the activty indicator.
            cell.activityIndicator.startAnimating()
            
            // Then download the photo (task happens on background thread) and convert to a UIImage.
            FlickrClient.sharedInstance().downloadFlickrPhoto(photoURL) { (photo, imageData, success, errorString) in
                if success {
                    // If photo download successful, add to data structure, and
                    // display that photo inside the cell, using the main thread.
                    let photoToSave = Photo(imageData: imageData! as NSData, context: self.sharedContext)
                    if let pin = self.selectedPin {
                        photoToSave.pin = pin
                        performUIUpdatesOnMain {
                            // Save the context after storing a photo in core data.
                            CoreDataStack.sharedInstance().saveContext()
                        }
                    }
                    
                    // Set image displayed in cell's imageView to the photo (UIImage) that was just downloaded.
                    performUIUpdatesOnMain {
                        cell.collectionCellImageView?.image = photo
                        // Stop animating the activity indicator once the image has been displayed in the cell.
                        cell.activityIndicator.stopAnimating()
                    }
                }
                else {
                    print(errorString!)
                }
            }
        }
        return cell
    }
    
    // MARK: Selecting photos
    
    // Allow user to select one or more photos from a pin's collection of photos.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        // Append the index path of just the selected cell to the array that tracks all cells currently selected.
        selectedCellIndexPaths.append(indexPath)
        
        // Change label of bar button when user selects at least one photo. If one or more
        // photos are selected, tapping the bar button will remove those photos.
        newCollectionBarButton.title = "Remove Selected Photos"
    }
    
    // MARK: Deselecting photos
    
    // Let user deselect multiple photos.
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        // Remove the index path of the just deselected cell from the array that tracks index paths of
        // all cells currently selected.
        if let pathToRemove = selectedCellIndexPaths.index(of: indexPath) {
            selectedCellIndexPaths.remove(at: pathToRemove)
        }

        // Once the final cell has been deselected, there are no more selected cells, which means the function
        // of the bar button changes back adding a new photo collection for the pin. Check for this case here and
        // update button's title text if necessary.
        if selectedCellIndexPaths.count == 0 {
            newCollectionBarButton.title = "New Collection"
        }
    }
}

// MARK: MKMapViewDelegate

extension PhotoAlbumViewController {
    
    // Define the style of the pins that appear on the map.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // Reverse geocoding a CLLocation object so that we can display a string representing its
    // compact address when user taps on the pin displayed in this controller's map view.
    func reverseGeoCode(_ location: CLLocation, completionHandlerForReverseGeoCode: @escaping (String) -> Void ) {
        
        // String that will contain the reverse geocoded address.
        var locationAddress: String = ""
        
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if error == nil {
                if let placemarks = placemarks, let placemark = placemarks.first, let locationAddress = placemark.compactAddress {
                    completionHandlerForReverseGeoCode(locationAddress)
                } else {
                    locationAddress = "No Matching Addresses Found"
                    completionHandlerForReverseGeoCode(locationAddress)
                }
            } else {
                locationAddress = "No Matching Addresses Found"
                completionHandlerForReverseGeoCode(locationAddress)
            }
        }
    }
}

// MARK: - CLPlacemark compact address

// Allows the display of a compact address string for any CLPlacemark object.
extension CLPlacemark {
    
    // Build a nicely formatted address if at least one component (country/state/postal code/
    // city/street) can be retrieved for the CLPlacemark object.
    var compactAddress: String? {
        
        // Will contain the nicely formatted address for the placemark.
        var resultAddress: String = ""
        
        // Temporarily store each component (country/state/postal code/city/street) of the
        // address if it exists.
        var addressComponentArray: [String] = []
        
        if let street = thoroughfare {
            addressComponentArray.append("\(street), ")
        }
        
        if let city = locality {
            addressComponentArray.append("\(city), ")
        }
        
        // If we have both state and postal code, display no comma in between them.
        // However, if we only have state or only have postal code, either must have a
        // comma displayed after it.
        if let state = administrativeArea, let postalCode = postalCode {
            addressComponentArray.append("\(state) \(postalCode), ")
        } else if let state = administrativeArea {
            addressComponentArray.append("\(state), ")
        } else if let postalCode = postalCode {
            addressComponentArray.append("\(postalCode), ")
        }
        
        if let country = country {
                addressComponentArray.append(country)
        }
        
        // Assemble the address string from its components, if there are any.
        if addressComponentArray.count > 0 {
            for component in addressComponentArray {
                resultAddress.append(component)
            }
        }
        
        // Return address if the result has at least one component.
        if resultAddress.count > 0 {
            // Make sure last two characters of result address are not ", "
            // (ie. there was no country component).
            
            // Index of second to last character in address string.
            let addressSecondToLastCharacterIndex = resultAddress.index(before: resultAddress.endIndex)
            // Make sure it doesn't have a comma.
            if resultAddress[addressSecondToLastCharacterIndex] == "," {
                resultAddress = String(resultAddress[..<addressSecondToLastCharacterIndex])
            }
            // And return the nicely formatted address result string.
            return resultAddress
        } else {
            // Otherwise return nil if the placemark contains zero commpents
            // which we would display in the address string.
            return nil
        }
    }
}


