//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/14/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class FlickrClient: NSObject {
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    // MARK: Shared managed object context
    
    var sharedContext = CoreDataStack.sharedInstance().managedObjectContext
    
    // Shared session
    let session = URLSession.shared
    
    // MARK: Get Flicker photos for a dropped pin
    
    // This method returns an array 45 randomly chosen Flickr photos for a pin's geographic coordinates
    // in its completion handler, or if any part of the process was unsuccessful, returns a string
    // describing the error.
    func getAndStoreFlickrPhotoURLsForPin(_ pin: Pin) {

        // Latitude and longitude of the pin
        let latitude = pin.latitude
        let longitude = pin.longitude
        
        // Method parameters for Flickr API calls.
        let methodParameters =
            [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.BoundingBox: latLongBoundaryBoxString(latitude, longitude),
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
        ]
        
        // Randomly choose a page from the Flickr search results for the lat-long coordinate pair of the pin.
        chooseRandomPageOfFlickrPhotoResults(methodParameters as [String:AnyObject]) { (pageNumber, success, errorString) in
            if success {
                // If successful, retrieve an array describing the photos on that page of search results.
                self.getFlickrPhotosFromPageInResults(methodParameters as [String : AnyObject], pageNumber: pageNumber!) { (flickrPhotoArrayForPage, success, errorString) in
                    if success {
                        // If successful, choose up to 45 photos at random from that page, and store in core data (as URLs).
                        self.randomlyChooseAndStorePhotoURLsFromFlickrPage(pin: pin, flickrPhotoArrayForPage: flickrPhotoArrayForPage!)
                    } else {
                        print(errorString as Any)
                    }
                }
            } else {
                print(errorString as Any)
            }
        }
    }
    
    // Generating the boundary box from the pin's lat-long coordinate to send to Flickr.
    private func latLongBoundaryBoxString(_ latitude: Double, _ longitude: Double) -> String {
        
        // Ensure bbox is bounded by minimum and maximums
        let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
    }
    
    // MARK: Download and store a photo from Flickr
    
    // Downloads image data from a photo's url and stores in core data. Returns a UIImage in
    // completion handler so that the photo can be displayed inside a collection view cell.
    func downloadAndStoreFlickrPhoto(_ photo: Photo, completionHandlerForDownloadAndStoreFlickrPhoto: @escaping (_ success: Bool, _ errorString: String?) -> Void) {
        
        // Download the photo and send to the completion handler.
        if let photoURL = photo.url {
            let imageURL = URL(string: photoURL)
            // Make sure image downloading happens on background thread.
            DispatchQueue.global(qos: .background).async {
                if let imageData = try? Data(contentsOf: imageURL!) {
                    
                    // Make sure that updates to core data happen on the main thread.
                    self.sharedContext.performAndWait {
                        // If successful, save the image data to the photo object in core data.
                        photo.imageData = imageData as NSData

                        // Save the context after saving the image data in core data.
                        CoreDataStack.sharedInstance().saveContext()
                    }
                                        
                    // If image data download successful, indicate this with completion handler.
                    self.sharedContext.performAndWait {
                        completionHandlerForDownloadAndStoreFlickrPhoto(true, nil)
                    }
                } else {
                    self.sharedContext.performAndWait {
                        let errorString = "Unable to download image from URL: \(imageURL!)"
                        completionHandlerForDownloadAndStoreFlickrPhoto(false, errorString)
                    }
                }
            }
        }
    }
    
    // MARK: Flickr API
    
    // Randomly choose a page of Flickr search results returned for a pin's
    // geographic coordinates.
    private func chooseRandomPageOfFlickrPhotoResults(_ methodParameters: [String: AnyObject], completionHandlerForChooseRandomPageOfFlickrPhotoResults: @escaping (_ pageNumber: Int?, _ success: Bool, _ errorString: String?) -> Void) {
        
        // Create the request.
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // Make the network request.
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // If an error occurs, send its description to the completion handler.
            func displayError(_ errorString: String) {
                completionHandlerForChooseRandomPageOfFlickrPhotoResults(nil, false, errorString)
            }

            // Parse the data and response from the Flickr API task. If no error, send a randomly chosen
            // page number from the Flickr search results to the completion handler.
            self.flickrTaskAndDataParsingHelper(data: data, response: response, error: error) { (photosDictionary, success, errorString) in
                if success {
                    /* GUARD: Is the "pages" key in the photosDictionary? */
                    guard let totalPages = photosDictionary![Constants.FlickrResponseKeys.Pages] as? Int else {
                        displayError("Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary!)")
                        return
                    }
                    
                    // Pick a random page. Flickr's API returns results containing a maximum of somewhere
                    // between 30 and 40 pages. Each returned page has 250 photos. Once a page is chosen at
                    // random, 45 photos will then be chosen at random from that page.
                    let pageLimit = min(totalPages, 30)
                    let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                    completionHandlerForChooseRandomPageOfFlickrPhotoResults(randomPage, true, nil)
                } else {
                    displayError(errorString!)
                }
            }
        }

        // Start the task.
        task.resume()
    }
    
    // Get photos from the randomly chosen Flickr search results page.
    private func getFlickrPhotosFromPageInResults(_ methodParameters: [String: AnyObject], pageNumber: Int, completionHandlerForGetFlickrPhotosFromPageInResults: @escaping (_ flickrPhotoArrayForPage: [[String:AnyObject]]?, _ success: Bool, _ errorString: String?) -> Void) {
        
        // Add the Flickr results page number to the method's parameters.
        var methodParametersWithPageNumber = methodParameters
        methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = pageNumber as AnyObject?
        
        // Create the request.
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // Make the network request.
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // If an error occurs, send its description to the completion handler.
            func displayError(_ errorString: String) {
                completionHandlerForGetFlickrPhotosFromPageInResults(nil, false, errorString)
            }

            // Parse the data and response from the Flickr API task. If no error, send to the completion
            // handler the array of photos from a page in the Flickr search results.
            self.flickrTaskAndDataParsingHelper(data: data, response: response, error: error) { (photosDictionary, success, errorString) in
                if success {
                    /* GUARD: Is the "photo" key in photosDictionary? */
                    guard let flickrPhotoArrayForPage = photosDictionary![Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                        displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary!)")
                        return
                    }
                    
                    /* GUARD: Are there any photos in the page of Flickr results? */
                    guard flickrPhotoArrayForPage.count != 0 else {
                        displayError("This pin has no images.")
                        return
                    }
                    
                    // If no errors, send the photo array from the Flickr results page to the
                    // completion handler.
                    completionHandlerForGetFlickrPhotosFromPageInResults(flickrPhotoArrayForPage, true, nil)
                } else {
                    displayError(errorString!)
                }
            }
        }
        
        // Start the task.
        task.resume()
    }
    
    // MARK: Randomly load photos from Flickr results page.
    
    // Randomly save up to 45 photo URLs from the Flickr results page as Photo objects in core data.
    private func randomlyChooseAndStorePhotoURLsFromFlickrPage(pin: Pin, flickrPhotoArrayForPage: [[String:AnyObject]?]) {
    
        // The number of photos on the Flickr results page.
        let numberOfPhotosOnPage = flickrPhotoArrayForPage.count
        
        // Randomly select at most 45 photos from the Flickr results page:
        
        // If less than 45 photos on results page, select them all.
        if numberOfPhotosOnPage < 45 {
            for entry in flickrPhotoArrayForPage {
                // Does the photo have a key for 'url_m'?
                if let entry = entry, let photoURLString = entry[Constants.FlickrResponseKeys.MediumURL] as? String {
                    
                    // Create a new photo object in core data under the pin and save the URL to this photo object.
                    savePhotoURLToCoreData(pin: pin, photoURL: photoURLString)
                }
            }
            
            // Save the context after storing all photo URLs in core data.
            performUIUpdatesOnMain {
                CoreDataStack.sharedInstance().saveContext()
            }
            
        } else {
            // If more than 45 photos, randomly choose 45 indices within the range of
            // number of photos on results page, and select those photos.
            var indicesOfPhotosAlreadyChosen: [Int] = []
            while indicesOfPhotosAlreadyChosen.count < 45 {
                let randomUniqueIndex = generateUniqueRandomIndexNumber(upperLimit: numberOfPhotosOnPage, indicesOfPhotosAlreadyChosen: indicesOfPhotosAlreadyChosen)
                
                // Track all randomly chosen indices so that we don't randomly choose
                // the same photo URL twice.
                indicesOfPhotosAlreadyChosen.append(randomUniqueIndex)
                
                // Does the photo have a key for 'url_m'?
                if let randomlyChosenPhotoEntry = flickrPhotoArrayForPage[randomUniqueIndex], let randomlyChosenPhotoURLString = randomlyChosenPhotoEntry[Constants.FlickrResponseKeys.MediumURL] as? String {
                    
                    // Create a new photo object in core data under the pin and save the URL to this photo object.
                    savePhotoURLToCoreData(pin: pin, photoURL: randomlyChosenPhotoURLString)
                }
            }
            
            // Save the context after storing all photo URLs in core data.
            performUIUpdatesOnMain {
                CoreDataStack.sharedInstance().saveContext()
            }
        }
    }

    // Saves a new photo object to core data under the pin parameter passed
    // to this method. Sets the object's url attribute to the URL passed
    // to this method.
    func savePhotoURLToCoreData(pin: Pin, photoURL: String) {
        
        // Updates to core data need to happen on the main thread.
        performUIUpdatesOnMain {
            // Create a new photo object in core data
            let photoToSave = Photo(context: self.sharedContext)
            // Set the url property of the newly created photo to the
            // URL string retrieved from Flickr.
            photoToSave.url = photoURL
            // Ensure that newly saved photo is associated with currently selected Pin
            photoToSave.pin = pin
        }
    }
    
    // MARK: Generate a unique random index number
    
    // Used to randomly choose photos from the Flickr results page to load and store.
    func generateUniqueRandomIndexNumber(upperLimit: Int, indicesOfPhotosAlreadyChosen: [Int]) -> Int {
        let randomIndexNumber = Int(arc4random_uniform(UInt32(upperLimit)))
        
        // Return the random number if it hasn't already been used.
        if !indicesOfPhotosAlreadyChosen.contains(randomIndexNumber) {
            return randomIndexNumber
        } else {
            // If the number has been used already, try again and choose a new number.
            return generateUniqueRandomIndexNumber(upperLimit: upperLimit, indicesOfPhotosAlreadyChosen: indicesOfPhotosAlreadyChosen)
        }
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

//MARK: Flickr API task data parsing helper method

extension FlickrClient {
    
    // The guard and data parsing statements that are shared by both calls to the Flickr API
    // (first call: to get page number; second call: to get array of photos from that page).
    func flickrTaskAndDataParsingHelper(data: Data?, response: URLResponse?, error: Error?, completionHandlerForFlickrTaskAndDataParsingHelper: @escaping (_ photosDictionary: [String:AnyObject]?, _ success: Bool, _ errorString: String?) -> Void) {
        /* GUARD: Was there an error? */
        guard (error == nil) else {
            let errorString = "There was an error with your request: \(String(describing: error))"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        /* GUARD: Did we get a successful 2XX response? */
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
            let errorString = "Your request returned a status code other than 2xx!"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        /* GUARD: Was there any data returned? */
        guard let data = data else {
            let errorString = "No data was returned by the request!"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        // Parse the data.
        let parsedResult: [String:AnyObject]!
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
        } catch {
            let errorString = "Could not parse the data as JSON: '\(data)'"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        /* GUARD: Did Flickr return an error (stat != ok)? */
        guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
            let errorString = "Flickr API returned an error. See error code and message in \(parsedResult)"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        /* GUARD: Is "photos" key in our result? */
        guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
            let errorString = "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)"
            completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
            return
        }
        
        completionHandlerForFlickrTaskAndDataParsingHelper(photosDictionary, true, nil)
    }
}


