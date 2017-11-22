<img src="https://s3-us-west-1.amazonaws.com/udacity-content/degrees/catalog-images/nd003.png" alt="iOS Developer Nanodegree logo" height="70" >

# Virtual Tourist App

![Platform iOS](https://img.shields.io/badge/nanodegree-iOS-blue.svg)

This repository contains the Virtual Tourist app project for the iOS Persistence and Core Data course in Udacity's iOS Nanodegree.

With the following user-friendly tweaks:

1. A more visually pleasing custom activity indicator spinner and gray-tinted overlay that appears underneath it. They are defined
    inside a custom class, and managed with a custom controller class. This makes it easy to call and dismiss the activity
    spinner during any network call, each with one line of code, from any view controller in the app:

    <img src="https://github.com/jamesdellinger/ios-nanodegree-on-the-map-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-13%20at%2020.56.28.png" height="400">
    
    <img src="https://github.com/jamesdellinger/ios-nanodegree-on-the-map-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-13%20at%2020.56.54.png" height="400">
    
    <img src="https://github.com/jamesdellinger/ios-nanodegree-on-the-map-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-13%20at%2020.57.44.png" height="400">

2. After user adds or updates their location information and taps 'FINISH,' the table and map views are automatically reloaded
    as the tab bar view controller containing them is popped back to. This is accomplished via a custom popToRootViewController()
    method defined in an extension to the UINavigationController class. Once the animation is completed, the custom method's
    completion handler calls the method that reloads the data and view for the map and table views.
    
    This means that the user doesn't have to tap the 'refresh' button in order to see the new location data they just entered get
    displayed. The new data will be right there waiting for them when the map/table view appears after they tap 'FINISH':

    <img src="https://github.com/jamesdellinger/ios-nanodegree-on-the-map-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-13%20at%2020.57.47.png" height="400">
