# iOS Developer Nanodegree: Virtual Tourist App
*Building a thread-safe app that uses Core Data to persist the app's state, settings, and downloaded photos.*

<img src="https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/iosndlogo.jpg" alt="iOS Developer Nanodegree logo" height="100" >

## Overview
This repository contains my Virtual Tourist app project for the **iOS Persistence and Core Data** course in Udacity's [iOS Nanodegree](https://www.udacity.com/course/ios-developer-nanodegree--nd003).

The Virtual Tourist app downloads and stores images from Flickr. The app allows users to drop pins on a map, as if they were stops on a tour. Users will then be able to download pictures for the location and persist both the pictures, and the association of the pictures with the pin.

My code is concurrency-tested and completely thread-safe.

## My Implementation's User-friendly Tweaks
1. Tapping "Edit" causes the map view to rise up, revealing the red bar underneath. Makes for greater similarity with how "Delete" indicators are revealed in other iOS elements, such as table views:

    <img src="https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-22%20at%2011.56.27.png" height="400">

2. Can tap on pin displayed above a location's photo album to reveal a nicely formatted address. If user has already dropped several pins, it can be easy to forget which pin's album is being viewed:

    <img src="https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-22%20at%2011.57.34.png" height="400">

3. Finally, it is possible to long press on any cell inside the collection view to display a larger size of a photo. The screen displaying this blown-up photo also contains an affordance that allows user to share the photo with any of their friends.

    <img src="https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-22%20at%2011.57.57.png" height="400">

    <img src="https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/Screenshots/Simulator%20Screen%20Shot%20-%20iPhone%208%20Plus%20-%202017-11-22%20at%2012.18.54.png" height="400">

## Project Grading and Evaluation
* [Project Review](https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/ios-nanodegree-virtual-tourist-app-review.pdf)

* [Project Grading Rubric](https://github.com/jamesdellinger/ios-nanodegree-virtual-tourist-app/blob/master/virtual-tourist-app-specs-and-rubric.pdf)
