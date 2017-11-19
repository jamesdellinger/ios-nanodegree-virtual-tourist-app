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

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    // MARK: Properties
    
    // An array of photos URLs associated with the pin.
    var pinPhotoURLs: [String]?
    // The pin that the user selected.
    var pin: MKPointAnnotation?
    // Index paths of collection cells that the user has selected
    var selectedCellIndexPaths: [IndexPath] = []
    // Number of cells to be displayed in the collectiom boew
    var numberOfItemsInSection: Int = 0
    
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
        displayPinInMapView(pin: pin!)
        
        // Get collection flow layout collection view controller first loads
        if UIDevice.current.orientation.isPortrait {
            setCollectionFlowLayout("Portrait")
        } else {
            setCollectionFlowLayout("Landscape")
        }
        
        // The collection view must allow multiple cells to be selected.
        collectionView.allowsMultipleSelection = true
        
        // If the pin doesn't already have any photos saved, load a new set of photos for the
        // pin so they can be displayed in the collection view.
        if PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.count == 0 {
            loadPinPhotos(pin!)
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
            PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]! = []
            loadPinPhotos(pin!)
        }
        
        // If title of bottom button is "Remove Selected Photos" we know that
        // at least one collection view cell has been selected, and function of
        // tapping this button should be deleting selected cells.
        
        if newCollectionBarButton.title == "Remove Selected Photos" {
            
            // Reload the data for the collection view so that performing the batch update
            // and deleting the cells from collection view throws no index errors.
            self.collectionView.reloadData()
            
            // Perform a batch update to display any and all cell deletion animations simultaneously.
            collectionView.performBatchUpdates({
                // Delete all corresponding photos from the data structure
                for path in selectedCellIndexPaths {
                    PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.remove(at: (path as NSIndexPath).item)
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
    
    func displayPinInMapView(pin: MKPointAnnotation) {
        
        // Get the pin's CLLocation so that pin's coordinates can be reverse geocoded.
        let pinLatitude = pin.coordinate.latitude
        let pinLongitude = pin.coordinate.longitude
        let pinLocation = CLLocation(latitude: pinLatitude, longitude: pinLongitude)
        
        // Reverse geocode the coordinates of the pin so that the resulting address string can
        // be displayed as the title of the map pin annotation if/when user taps on the pin.
        reverseGeoCode(pinLocation) { (locationAddress) in
            
            // Set the title of the annotation to the address that was
            // reverse geo coded. (Returns "No Matching Addresses Found" if
            // reverse geocode lookup was unsuccessful.)
            pin.title = locationAddress
            
            // Add the pin annotation to the map.
            self.pinMapView.addAnnotation(pin)
            
            // Make sure the map is centered on this one annotation.
            self.pinMapView.centerCoordinate = pin.coordinate
            
            // And make sure the map is zoomed in fairly close in to the pin.
            self.pinMapView.camera.altitude = 1000.0
        }
    }
    
    // MARK: Load a new set of images for a pin
    
    func loadPinPhotos(_ pin: MKPointAnnotation) {
        // Get an array of Flickr URL strings for Flickr photos taken at or near
        // the geographic coordinates of the selected pin.
        let latitude = pin.coordinate.latitude
        let longitude = pin.coordinate.longitude
        
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
                controller.photo = PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]![(indexPath as NSIndexPath).item]
                
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
        
        if PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.count > 0 {
            numberOfItemsInSection = PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.count
        } else if let pinPhotoURLs = pinPhotoURLs {
            numberOfItemsInSection = pinPhotoURLs.count
        } else {
            numberOfItemsInSection = 0
        }
        return numberOfItemsInSection
    }
    
    // MARK: Display cells
    
    // Dequeue cells as they are displayed in the meme collection view controller
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // The cell to be dequeued
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        // If a photo corresponding to the cell's item index has been stored in the data structure,
        // then display that stored photo in the cell.
        if PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.count > (indexPath as NSIndexPath).item {
            if let storedPhoto = PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]![(indexPath as NSIndexPath).item] as UIImage? {
                cell.collectionCellImageView?.image = storedPhoto
            }
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
            FlickrClient.sharedInstance().downloadFlickrPhoto(photoURL) { (photo, success, errorString) in
                if success {
                    // If photo download successful, add to data structure, and
                    // display that photo inside the cell, using the main thread.
                    PinsAndPhotosDataStructure.locationsAndPhotos[self.pin!]!.append(photo!)
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

/* Allows the display of a compact address string for any CLPlacemark object. */
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


