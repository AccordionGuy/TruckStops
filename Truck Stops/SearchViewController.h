//
//  SearchViewController.h
//  Truck Stops
//
//  Created by Joey deVilla on 5/25/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MapViewController.h"

@interface SearchViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) MapViewController *delegate;

@end
