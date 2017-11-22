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
    // Index paths of collection cells that the user has selected.
    var selectedCellIndexPaths = [IndexPath]()
    // Keep track of collection cell insertions, and deletions.
    var insertedCellIndexPaths: [IndexPath]!
    var deletedCellIndexPaths: [IndexPath]!
    
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
        performPhotoFetchRequest(photoFetchedResultsController)
        
        // If the pin doesn't already have any photos saved in core data,
        // retrieve up to 45 random photo URLs from Flickr and save a
        // Photo object in core data under the selected pin, for each of these URLs.
        if let fetchedPhotosForPin = photoFetchedResultsController.fetchedObjects, fetchedPhotosForPin.count == 0 {
            FlickrClient.sharedInstance().getAndStoreFlickrPhotoURLsForPin(self.selectedPin!)
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
        
        // If any photo cells are selected, tapping bottom button deletes them.
        if bottomButtonDeletesSelectedPhotos() {
            deletePhotos()
        } else {
            getNewCollections()
        }
    }
    
    // If title of bottom button is "New Collection" we know that no collection
    // view cells have been selected and so tapping this button should load and store
    // a fresh set of photos from Flickr for the pin.
    func bottomButtonDeletesSelectedPhotos() -> Bool {
        if newCollectionBarButton.title == "New Collection" {
            return false
        } else {
            return true
        }
    }
    
    // Delete all the pin's photos from core data, and reload a new batch
    // of photos and save to them to the pin.
    func getNewCollections() {
        // Clear the photos stored in the data structure.
        if let storedPhotos = photoFetchedResultsController.fetchedObjects {
            for photo in storedPhotos {
                sharedContext.delete(photo)
            }
            
            // Save the context after deleting all of the pin's photos from core data.
            performUIUpdatesOnMain {
                CoreDataStack.sharedInstance().saveContext()
            }
        }
        
        // Retrieve a new set of photo URLs from flickr and save them as
        // Photo objects under the selected pin.
        FlickrClient.sharedInstance().getAndStoreFlickrPhotoURLsForPin(self.selectedPin!)
    }
    
    // Delete all selected photos from core data.
    func deletePhotos() {
        for indexPath in selectedCellIndexPaths {
            if let photos = photoFetchedResultsController.fetchedObjects {
                sharedContext.delete(photos[(indexPath as NSIndexPath).item])
                performUIUpdatesOnMain {
                    // Save the context after deleting a photo from core data.
                    CoreDataStack.sharedInstance().saveContext()
                }
            }
        }
        // Reset array that tracks selected cells now that all selected cells have been deleted.
        selectedCellIndexPaths.removeAll()
        
        // Also change title of bar button back to "New Collection"
        updateBottomButtonTitle()
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
    
    // MARK: Perform photo fetch request
    
    // Make the photo fetch request, taking as a parameter a the fetched results controller created
    // by the photoFetchedResultsController lazy var.
    func performPhotoFetchRequest(_ photoFetchedResultsController: NSFetchedResultsController<Photo>?) {
        if let photoFetchedResultsController = photoFetchedResultsController {
            var photoFetchError: NSError?
            do {
                try photoFetchedResultsController.performFetch()
            } catch let error as NSError {
                photoFetchError = error
            }
            
            if let photoFetchError = photoFetchError {
                print("Error performing photo fetch: \(photoFetchError)")
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
                if let storedPhotoForCell = photoFetchedResultsController.fetchedObjects?[(indexPath as NSIndexPath).item], let storedPhotoImageData = storedPhotoForCell.imageData {
                    controller.photo = UIImage(data: storedPhotoImageData as Data)
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
        
        // Number of photos associated with the pin (initial default is 0, will  be
        // updated with amount of Photo objects (either as a URL or imageData) fetched
        // with the fetched results controller.
        var numberOfFetchedPhotos = 0

        if let fetchedPhotos  = photoFetchedResultsController.fetchedObjects {
            numberOfFetchedPhotos = fetchedPhotos.count
        }
        return numberOfFetchedPhotos
    }
    
    // MARK: Display cells
    
    // Dequeue cells as they are displayed in the meme collection view controller
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // The cell to be dequeued
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        // Display the placeholder image in the cell, which will remain visible until the photo
        // that exists at the URL is loaded.
        cell.collectionCellImageView?.image = #imageLiteral(resourceName: "default-placeholder")

        // Also begin animating the activty indicator.
        cell.activityIndicator.startAnimating()
        
        // If there is at least one Photo stored in core data for the current Pin, display each stored
        // Photo in its corresponding collection view cell.
        if let fetchedPhotos = photoFetchedResultsController.fetchedObjects, fetchedPhotos.count > 0 {

            // The Photo stored in core data that corresponds to this particular cell
            let storedPhotoForCell = fetchedPhotos[(indexPath as NSIndexPath).item]
            
            // If stored image data is present for the cell's Photo, then convert to a
            // UIImage and display within cell's imageview.
            if let storedImageDataForPhoto = storedPhotoForCell.imageData {
                
                cell.collectionCellImageView?.image = UIImage(data: storedImageDataForPhoto as Data)
                
                // Stop animating the activity indicator once the image has been displayed in the cell.
                cell.activityIndicator.stopAnimating()
                
            } else {
                
                // If no photo image data has been stored for the Photo, as long as the photo object has
                // a url stored, then download the image data right now from the Photo's stored URL.
                if storedPhotoForCell.url != nil {
                    
                    // Download the photo's image data and store in core data.
                    FlickrClient.sharedInstance().downloadAndStoreFlickrPhoto(storedPhotoForCell) { (success, errorString) in
                        if success {
                            // If image data download and storage successful, retrieve the latest
                            // photos data for the pin.
                            self.performPhotoFetchRequest(self.photoFetchedResultsController)
                            // Then reload the collection view so that the
                            // just-downloaded photo will be displayed in the cell.
                            performUIUpdatesOnMain {
                                self.collectionView.reloadData()
                            }
                        }
                        else {
                            print(errorString!)
                        }
                    }
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
        updateBottomButtonTitle()
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
        updateBottomButtonTitle()
    }
    
    func updateBottomButtonTitle() {
        if selectedCellIndexPaths.count > 0 {
            newCollectionBarButton.title = "Remove Selected Photos"
        } else {
            newCollectionBarButton.title = "New Collection"
        }
    }
}

// MARK: Fetched Results Controller Delegate

extension PhotoAlbumViewController {
    
    // The following three methods are invoked whenever changes are made to Core Data:
    
    // Creates two fresh arrays to record the index paths that will be changed.
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        // Start out with empty arrays for each change type (insert or delete).
        insertedCellIndexPaths = [IndexPath]()
        deletedCellIndexPaths = [IndexPath]()
    }
    
    // Keep track of everytime a Photo object is added or deleted.
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
            
        case .insert:
            // Tracking when a new Photo object has been added to core data.
            insertedCellIndexPaths.append(newIndexPath!)
            break
        case .delete:
            // Tracking when a Photo object has been deleted from Core Data.
            deletedCellIndexPaths.append(indexPath!)
            break
        default:
            break
        }
    }
    
    // Invoked after all of the changed objects in the current batch have been collected
    // into the two index path arrays (insert,  or delete).
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {

        // Loop through the arrays and perform the changes in one fell swoop (as a batch).
        collectionView.performBatchUpdates({() -> Void in
            for indexPath in self.insertedCellIndexPaths {
                self.collectionView.insertItems(at: [indexPath])
            }
            for indexPath in self.deletedCellIndexPaths {
                self.collectionView.deleteItems(at: [indexPath])
            }
        }, completion: nil)
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


