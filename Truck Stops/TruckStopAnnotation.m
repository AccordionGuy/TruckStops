//
//  TruckStopAnnotation.m
//  Truck Stops
//
//  Created by Joey deVilla on 5/5/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import "TruckStopAnnotation.h"

@implementation TruckStopAnnotation

- (id)initWithTitle:(NSString *)newTitle Location:(CLLocationCoordinate2D)location {
  self = [super init];

  if (self) {
    _title = newTitle;
    _coordinate = location;
  }
  
  return self;
}

- (MKAnnotationView *)annotationView {
  MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:self
                                                                  reuseIdentifier:@"TruckStopAnnotation"];
  annotationView.enabled = YES;
  annotationView.canShowCallout = YES;
  annotationView.image = [UIImage imageNamed:@"truck pin"];
  annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeInfoLight];

  return annotationView;
}

@end
