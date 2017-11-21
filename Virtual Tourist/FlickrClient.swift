//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/14/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import Foundation
import UIKit

class FlickrClient: NSObject {
    
//    // MARK: Properties
//    var flickrPhotosForLatLon: [UIImage] = []
    
    // Shared session
    let session = URLSession.shared
    
    // MARK: Get Flicker photos for a dropped pin
    
    // This method returns an array 45 randomly chosen Flickr photos for a pin's geographic coordinates
    // in its completion handler, or if any part of the process was unsuccessful, returns a string
    // describing the error.
    func getFlickrPhotosURLArrayForPin(_ latitude: Double, _ longitude: Double, completionHandlerForGetFlickrPhotosURLArrayForPin: @escaping (_ flickrPhotosURLArrayForPin: [String]?, _ success: Bool, _ errorString: String?) -> Void) {
        
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
                        // If successful, choose up to 45 photos at random from that page.
                        self.choosePhotoURLsFromFlickrPage(flickrPhotoArrayForPage!) { (flickrPhotosURLArrayForPin, success, errorString) in
                            if success {
                                // Finally, if successful, send the pin's photo URL array to the completion handler.
                                completionHandlerForGetFlickrPhotosURLArrayForPin(flickrPhotosURLArrayForPin, true, nil)
                            } else {
                                completionHandlerForGetFlickrPhotosURLArrayForPin(nil, false, errorString)
                            }
                        }
                    } else {
                        completionHandlerForGetFlickrPhotosURLArrayForPin(nil, false, errorString)
                    }
                }
            } else {
                completionHandlerForGetFlickrPhotosURLArrayForPin(nil, false, errorString)
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
                    // between 30 and 40 pages.
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
    
    // Randomly select up to 45 photo URLs from the Flickr results page.
    private func choosePhotoURLsFromFlickrPage(_ flickrPhotoArrayForPage: [[String:AnyObject]], completionHandlerForChoosePhotoURLsFromFlickrPage: @escaping (_ flickrPhotosURLArrayForPin: [String]?, _ success: Bool, _ errorString: String?) -> Void) {
        
        // The array of photos for the pin (coordinate pair)
        var flickrPhotosURLArrayForPin: [String] = []
        
        // The number of photos on the Flickr results page.
        let numberOfPhotosOnPage = flickrPhotoArrayForPage.count
        
        // Randomly select at least 45 photos from the Flickr results page:
        
        // If less than 45 photos on results page, select them all.
        if numberOfPhotosOnPage < 45 {
            for entry in flickrPhotoArrayForPage {
                // Does the photo have a key for 'url_m'?
                if let photoURLString = entry[Constants.FlickrResponseKeys.MediumURL] as? String {
                    flickrPhotosURLArrayForPin.append(photoURLString)
                }
            }
        } else {
            // If more than 45 photos, randomly choose 45 indices within the range of
            // number of photos on results page, and select those photos.
            var indicesOfPhotosAlreadyChosen: [Int] = []
            while flickrPhotosURLArrayForPin.count < 45 {
                let randomUniqueIndex = generateUniqueRandomIndexNumber(upperLimit: numberOfPhotosOnPage, indicesOfPhotosAlreadyChosen: indicesOfPhotosAlreadyChosen)
                indicesOfPhotosAlreadyChosen.append(randomUniqueIndex)
                let photoEntry = flickrPhotoArrayForPage[randomUniqueIndex]
                // Does the photo have a key for 'url_m'?
                if let photoURLString = photoEntry[Constants.FlickrResponseKeys.MediumURL] as? String {
                    flickrPhotosURLArrayForPin.append(photoURLString)
                }
            }
        }
        
        // If at least one photo URL has been selected and added to the given pin's (coordinate pair's)
        // photo URL array, send the pin's photo URL array to the completion handler.
        if flickrPhotosURLArrayForPin.count > 0 {
            completionHandlerForChoosePhotoURLsFromFlickrPage(flickrPhotosURLArrayForPin, true, nil)
        } else {
            let errorString = "This pin has no images."
            completionHandlerForChoosePhotoURLsFromFlickrPage(nil, false, errorString)
        }
    }
    
    // MARK: Load a photo from Flickr
    
    // Downloads a photo from a Flickr photo URL.
    func downloadFlickrPhoto(_ flickrPhotoURL: String, completionHandlerForDownloadFlickrPhoto: @escaping (_ photo: UIImage?, _ imageData: Data?, _ success: Bool, _ errorString: String?) -> Void) {
        // Make sure image downloading happens on background thread.
        DispatchQueue.global(qos: .background).async {
            // Download the photo and send to the completion handler.
            let imageURL = URL(string: flickrPhotoURL)
            if let imageData = try? Data(contentsOf: imageURL!) {
                // If successful, convert data to a UIImage
                let photo = UIImage(data: imageData)
                completionHandlerForDownloadFlickrPhoto(photo, imageData, true, nil)
            } else {
                let errorString = "Unable to download image from URL: \(imageURL!)"
                completionHandlerForDownloadFlickrPhoto(nil, nil, false, errorString)
            }
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
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
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


