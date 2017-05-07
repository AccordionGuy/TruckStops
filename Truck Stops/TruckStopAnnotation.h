//
//  TruckStopAnnotation.h
//  Truck Stops
//
//  Created by Joey deVilla on 5/5/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface TruckStopAnnotation : NSObject <MKAnnotation>

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;
@property (copy, nonatomic) NSString *address;

- (id)initWithTitle:(NSString *)newTitle Location:(CLLocationCoordinate2D)location;
- (MKAnnotationView *)annotationView;

@end
