//
//  ViewController.m
//  Truck Stops
//
//  Created by Joey deVilla on 5/2/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import "MapViewController.h"
#import "UNIRest.h"
#import "TruckStopAnnotation.h"

@interface MapViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *viewSelector;
@property (weak, nonatomic) IBOutlet UIButton *currentLocationButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

typedef enum {
  kTrackingOff,
  kTrackingTemporarilyOff,
  kTrackingOn
} TrackingMode;

const int METERS_PER_MILE = 1609.34;

@implementation MapViewController {
  CLLocationManager *locationManager;

  CLLocation *currentLocation;
  MKCoordinateRegion lastKnownRegion;
  CLLocationCoordinate2D lastKnownCenterCoordinate;


  TrackingMode currentTrackingMode;

  bool isInTrackingMode;
  bool userIsReadingDetails;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  locationManager = [[CLLocationManager alloc] init];
  locationManager.delegate = self;
  // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
  if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
    [locationManager requestWhenInUseAuthorization];
  }
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  [locationManager startUpdatingLocation];

  self.mapView.delegate = self;
  [self.mapView setUserTrackingMode:MKUserTrackingModeFollow];
  self.mapView.showsTraffic = YES;
  self.mapView.showsUserLocation = YES;

  // Initialize segmented control
  self.viewSelector.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderColor = [UIColor whiteColor].CGColor;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  // Initialize current location button
  self.currentLocationButton.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  [self.activityIndicator stopAnimating];

  // TODO: Get this values from UserDefaukts
  currentTrackingMode = kTrackingOn;

  userIsReadingDetails = NO;

  [self displayCurrentLocationAtDefaultZoom];
}


- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (IBAction)userChangedMapView:(UISegmentedControl *)sender {
  switch (sender.selectedSegmentIndex) {
    case 0:
      self.mapView.mapType = MKMapTypeStandard;
      break;
    case 1:
      self.mapView.mapType = MKMapTypeHybrid;
      break;
    default:
      self.mapView.mapType = MKMapTypeStandard;
      break;
  }
}

- (IBAction)currentLocationButtonTapped:(UIButton *)sender {
  [self displayCurrentLocationAtDefaultZoom];
//  int radius = 100;
//  [self getTruckStopDataForLatitude:currentLocation.coordinate.latitude
//                       andLongitude:currentLocation.coordinate.longitude
//                  withRadiusInMiles:radius];
}

- (void)getTruckStopDataForLatitude:(double)latitude
                       andLongitude:(double)longitude
                  withRadiusInMiles:(int)radius {
  if (latitude == 0.0 && longitude == 0.0) {
    return;
  }

  [self.activityIndicator startAnimating];

  NSDictionary *headers = @{
    @"Content-Type": @"application/json",
    @"Authorization": @"Basic amNhdGFsYW5AdHJhbnNmbG8uY29tOnJMVGR6WmdVTVBYbytNaUp6RlIxTStjNmI1VUI4MnFYcEVKQzlhVnFWOEF5bUhaQzdIcjVZc3lUMitPTS9paU8="
  };

  NSString *formattedLat = [NSString stringWithFormat:@"%f", latitude];
  NSString *formattedLng = [NSString stringWithFormat:@"%f", longitude];
  NSLog(@"formattedLat: %@ - formattedLng: %@", formattedLat, formattedLng);
  NSDictionary *parameters = @{
    @"lat": formattedLat,
    @"lng": formattedLng
  };
  NSString *urlString = [NSString stringWithFormat:@"http://webapp.transflodev.com/svc1.transflomobile.com/api/v3/stations/%d", radius];
  NSLog(@"urlString: %@", urlString);

  [[UNIRest post:^(UNISimpleRequest *request) {
    [request setUrl:urlString];
    [request setHeaders:headers];
    [request setParameters:parameters];
  }] asJsonAsync:^(UNIHTTPJsonResponse* response, NSError *error) {
    // This is the asyncronous callback block
    NSInteger code = response.code;
    NSDictionary *responseHeaders = response.headers;
    UNIJsonNode *body = response.body;
    NSData *rawBody = response.rawBody;

    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:rawBody
                                                             options:kNilOptions
                                                               error:nil];
    NSArray *truckStops = jsonDict[@"truckStops"];
    NSLog(@"Number of truck stops: %lu", (unsigned long)[truckStops count]);

    if ([truckStops count] > 0) {
      for (NSDictionary *truckStop in truckStops) {
        NSString *title = [NSString stringWithFormat:@"%@", truckStop[@"name"]];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([truckStop[@"lat"] doubleValue],
                                                                       [truckStop[@"lng"] doubleValue]);
        TruckStopAnnotation *point = [[TruckStopAnnotation alloc] initWithTitle:title
                                                                       Location:coordinate];
        point.subtitle = [NSString stringWithFormat:@"%@, %@", truckStop[@"city"], truckStop[@"state"]];
        point.address = [NSString stringWithFormat:@"%@\n%@", truckStop[@"rawLine1"], truckStop[@"rawLine2"]];
        [self.mapView addAnnotation:point];
      }
    }
  }];

  [self.activityIndicator stopAnimating];
}

- (void)getCurrentLocation {
  locationManager.delegate = self;
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;

  [locationManager startUpdatingLocation];
}

- (void)displayCurrentLocationAtDefaultZoom {
  NSLog(@"displayCurrentLocationAtDefaultZoom");
  CLLocationCoordinate2D startCoord = CLLocationCoordinate2DMake(currentLocation.coordinate.latitude,
                                                                 currentLocation.coordinate.longitude);
  MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:MKCoordinateRegionMakeWithDistance(startCoord, 160000, 160000)];
  [self.mapView setRegion:adjustedRegion animated:YES];
  int radius = 100;
  [self getTruckStopDataForLatitude:currentLocation.coordinate.latitude
                       andLongitude:currentLocation.coordinate.longitude
                  withRadiusInMiles:radius];

//  const double DEFAULT_MAP_SIZE = 200;
//
//  CLLocationCoordinate2D centerCoordinate = CLLocationCoordinate2DMake(currentLocation.coordinate.latitude,
//                                                                       currentLocation.coordinate.longitude);
//  self.mapView.camera.altitude = 160000;
//  [self.mapView setCenterCoordinate:centerCoordinate animated:YES];
//  MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, milesToMeters(DEFAULT_MAP_SIZE), milesToMeters(DEFAULT_MAP_SIZE));
//  [self.mapView setRegion:region animated:YES];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  NSLog(@"Touches began");
  lastKnownRegion = self.mapView.region;

  if (currentTrackingMode == kTrackingOn) {
    currentTrackingMode = kTrackingTemporarilyOff;
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  NSLog(@"Touches ended");
  if (currentTrackingMode == kTrackingTemporarilyOff) {
    [self performSelector:@selector(centerMap) withObject:self afterDelay:5];
    currentTrackingMode = kTrackingOn;
  }
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
}

// Map position or zoom level changed
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
  NSLog(@"regionDidChangeAnimated");

  // Zoom limit for map
  const double MAXIMUM_CAMERA_ALTITUDE = 1500000.0; // Make the map about 200 miles wide in portrait,
                                                    // and 350 miles wide in landscape.
  const double CAMERA_ZOOM_THRESHOLD_ALTITUDE = MAXIMUM_CAMERA_ALTITUDE + 1000;

  if (mapView.camera.altitude > CAMERA_ZOOM_THRESHOLD_ALTITUDE) {
    NSLog(@"Rezooming camera");
    mapView.camera.altitude = MAXIMUM_CAMERA_ALTITUDE;
  }

  // Limit user to the United States and Canada
  const double NORTHERNMOST_LATITUDE = 72.0;    // Northern edge of Alaska
  const double SOUTHERNMOST_LATITUDE = 24.0;    // Key West
  const double WESTERNMOST_LONGITUDE = -179.0;  // Aleutian islands
  const double EASTERNMOST_LONGITUDE = -50.0;   // Newfoundland

  if ((mapView.centerCoordinate.latitude  > NORTHERNMOST_LATITUDE) ||
      (mapView.centerCoordinate.latitude  < SOUTHERNMOST_LATITUDE) ||
      (mapView.centerCoordinate.longitude < WESTERNMOST_LONGITUDE) ||
      (mapView.centerCoordinate.longitude > EASTERNMOST_LONGITUDE)) {
    NSLog(@"Repositioning camera");
    if (lastKnownCenterCoordinate.latitude != 0.0 && lastKnownCenterCoordinate.longitude != 0.0) {
      [mapView setRegion:lastKnownRegion animated:YES];
    } else {
      return;
    }
  }

  float largestMapViewSpan;
  if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
    largestMapViewSpan = metersToMiles([self mapViewLatitudeInMeters:mapView]);
  } else {
    largestMapViewSpan = metersToMiles([self mapViewLongitudeInMeters:mapView]);
  }
  if (largestMapViewSpan < 1.0) {
    largestMapViewSpan = 1.0;
  }
  int radius = (int)round(largestMapViewSpan);
  [self getTruckStopDataForLatitude:mapView.centerCoordinate.latitude
                       andLongitude:mapView.centerCoordinate.longitude
                  withRadiusInMiles:radius];

  if (currentTrackingMode == kTrackingTemporarilyOff) {
    [self performSelector:@selector(centerMap) withObject:self afterDelay:5];
    currentTrackingMode = kTrackingOn;
  }
}

- (int)mapViewLatitudeInMeters:(MKMapView *)mapView {
  MKCoordinateSpan span = mapView.region.span;
  CLLocationCoordinate2D center = mapView.region.center;

  //get latitude in meters
  CLLocation *topEdgeCenter = [[CLLocation alloc] initWithLatitude:(center.latitude - span.latitudeDelta * 0.5) longitude:center.longitude];
  CLLocation *bottomEdgeCenter = [[CLLocation alloc] initWithLatitude:(center.latitude + span.latitudeDelta * 0.5) longitude:center.longitude];
  return [topEdgeCenter distanceFromLocation:bottomEdgeCenter];
}

- (int)mapViewLongitudeInMeters:(MKMapView *)mapView {
  MKCoordinateSpan span = mapView.region.span;
  CLLocationCoordinate2D center = mapView.region.center;

  //get longitude in meters
  CLLocation *leftEdgeCenter = [[CLLocation alloc] initWithLatitude:center.latitude longitude:(center.longitude - span.longitudeDelta * 0.5)];
  CLLocation *rightEdgeCenter = [[CLLocation alloc] initWithLatitude:center.latitude longitude:(center.longitude + span.longitudeDelta * 0.5)];
  return [leftEdgeCenter distanceFromLocation:rightEdgeCenter];
}

- (void)centerMap {
//  NSLog(@"centerMap");
//  [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
  if ([annotation isKindOfClass:[TruckStopAnnotation class]]) {
    TruckStopAnnotation *truckStopAnnotation = (TruckStopAnnotation *)annotation;
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"TruckStopAnnotation"];
    if (annotationView == nil) {
      annotationView = truckStopAnnotation.annotationView;
    } else {
      annotationView.annotation = annotation;
    }
    [annotationView setImage:[UIImage imageNamed:@"truck pin"]];

    CLLocationCoordinate2D annotationCoordinate = annotationView.annotation.coordinate;
    CLLocation *annotationLocation = [[CLLocation alloc] initWithLatitude:annotationCoordinate.latitude
                                                                longitude:annotationCoordinate.longitude];
    int distance = (int)round(metersToMiles([currentLocation distanceFromLocation:annotationLocation]));

    UILabel *detailLabel;
    detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 60)];
    [detailLabel setFont:[UIFont systemFontOfSize:14.0]];
    detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    detailLabel.numberOfLines = 0;
    detailLabel.text = [NSString stringWithFormat:@"%@\n%@", truckStopAnnotation.subtitle, truckStopAnnotation.address];
    annotationView.detailCalloutAccessoryView = detailLabel;

    UILabel *rightLabel;
    rightLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 60)];
    [rightLabel setFont:[UIFont systemFontOfSize:12.0]];
    rightLabel.lineBreakMode = NSLineBreakByWordWrapping;
    rightLabel.numberOfLines = 0;
    rightLabel.text = [NSString stringWithFormat:@"%d miles away", distance];
    annotationView.rightCalloutAccessoryView = rightLabel;

    return annotationView;
  }
  else {
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"UserAnnotation"];
    if (annotationView == nil) {
      annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"UserAnnotation"];
    } else {
      annotationView.annotation = annotation;
    }
    [annotationView setImage:[UIImage imageNamed:@"user pin"]];
    annotationView.canShowCallout = YES;
    return annotationView;
  }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
  id<MKAnnotation> annotation = view.annotation;
  if ([annotation isKindOfClass:[TruckStopAnnotation class]]) {
    TruckStopAnnotation *truckStopAnnotation = (TruckStopAnnotation *)annotation;
    NSLog(@"TAPPED! %@", truckStopAnnotation.title);
  }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  NSLog(@"locationManager:didFailWithError:");
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  currentLocation = locations.lastObject;
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {

}

double milesToMeters(double miles) {
  return miles * METERS_PER_MILE;
}

double metersToMiles(double meters) {
  return meters / METERS_PER_MILE;
}

@end

