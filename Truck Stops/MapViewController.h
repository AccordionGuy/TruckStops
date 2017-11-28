//
//  ViewController.h
//  Truck Stops
//
//  Created by Joey deVilla on 5/2/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Reachability.h"


@interface MapViewController : UIViewController <MKMapViewDelegate, CLLocationManagerDelegate> {
  Reachability *networkReachableDetector;
}

- (void)changeSearchMode;

@property (copy, nonatomic) NSString *searchName;
@property (copy, nonatomic) NSString *searchCity;
@property (copy, nonatomic) NSString *searchState;
@property (copy, nonatomic) NSString *searchZip;

@end

