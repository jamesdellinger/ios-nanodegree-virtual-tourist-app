//
//  PhotoDetailViewController.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/17/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import Foundation
import UIKit

// This view controller displays a large size of a photo whose cell
// the user long-pressed on. Share button allows user to share the
// photo with a friend. 

class PhotoDetailViewController: UIViewController {
    
    // MARK: Properties
    
    // The photo to be displayed.
    var photo: UIImage?
    
    // MARK: IBOutlet
    
    //Image view in which the photo will be displayed.
    @IBOutlet weak var photoImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display the photo.
        photoImageView?.image = photo
    }
    
    // MARK: Share the photo
    
    @IBAction func sharePhoto(_ sender: Any) {
        
        let activityController = UIActivityViewController(activityItems: [photo!], applicationActivities: nil)
        // Present the activity controller
        self.present(activityController, animated: true, completion: nil)
        
        // If user completes an activity inside activity controller, such as sharing,
        // immediately pop back to the pin's photo collection view in the previous view controller.
        activityController.completionWithItemsHandler = {(activityType: UIActivityType?, completed:Bool, returnedItems:[Any]?, error: Error?) in
            // But if user cancels without completing an activity in activity controller, then
            // view should stay on the current screen.
            if !completed {
                return
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}
