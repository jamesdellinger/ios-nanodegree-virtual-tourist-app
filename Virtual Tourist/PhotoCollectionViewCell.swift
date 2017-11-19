//
//  PhotoCollectionViewCell.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/14/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//

import Foundation
import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    // MARK: Outlets
    
    // Imageview for displaying a photo.
    @IBOutlet weak var collectionCellImageView: UIImageView!
    
    // Activity indicator that animates while an image is
    // being downloaded.
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // Change alpha of any selected cell to 0.3 so that user can
    // see which cells they've selected.
    override var isSelected: Bool {
        didSet {
            collectionCellImageView.alpha = isSelected ? 0.3 : 1.0
        }
    }
}
