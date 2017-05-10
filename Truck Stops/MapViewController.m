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

  BOOL firstRun;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  NSLog(@"ViewDidLoad");

  firstRun = true;
  [self testInternetConnection];

  locationManager = [[CLLocationManager alloc] init];
  locationManager.delegate = self;
  [self checkLocationAuthorizationStatus];
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  [locationManager startUpdatingLocation];

  self.mapView.delegate = self;
  self.mapView.showsTraffic = YES;

  // Initialize segmented control
  self.viewSelector.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderColor = [UIColor whiteColor].CGColor;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  // Initialize current location button
  self.currentLocationButton.layer.cornerRadius = 7.0;
  self.currentLocationButton.layer.borderColor = [UIColor whiteColor].CGColor;
  self.currentLocationButton.layer.borderWidth = 4.0f;
  self.currentLocationButton.layer.masksToBounds = YES;

  [self.activityIndicator stopAnimating];

  // TODO: Get this values from UserDefaukts
  currentTrackingMode = kTrackingOn;

  userIsReadingDetails = NO;

//  [self performSelector:@selector(centerMapOnCurrentLocation) withObject:self afterDelay:1];
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
  [self centerMapOnCurrentLocation];
//  [self displayCurrentLocationAtDefaultZoom];
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

    if (!rawBody) {
      NSLog(@"NO RAW BODY __ NETWORK SHAT ITSELF");
      return;
    }

    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:rawBody
                                                             options:kNilOptions
                                                               error:nil];
    NSArray *truckStops = jsonDict[@"truckStops"];
    NSUInteger numTruckStops = [truckStops count];
    NSLog(@"Number of truck stops: %lu", numTruckStops);

    if (numTruckStops > 0) {
      NSLog(@"Adding annotations");
      for (NSDictionary *truckStop in truckStops) {
        NSString *title = [NSString stringWithFormat:@"%@", truckStop[@"name"]];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([truckStop[@"lat"] doubleValue],
                                                                       [truckStop[@"lng"] doubleValue]);
        TruckStopAnnotation *point = [[TruckStopAnnotation alloc] initWithTitle:title
                                                                       Location:coordinate];
        point.subtitle = [NSString stringWithFormat:@"%@, %@", truckStop[@"city"], truckStop[@"state"]];
        point.address = [NSString stringWithFormat:@"%@\n%@", truckStop[@"rawLine1"], truckStop[@"rawLine2"]];
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.mapView addAnnotation:point];
        });

      }
    }
  }];

  [self.activityIndicator stopAnimating];
}

- (void)getCurrentLocation {
//  locationManager.delegate = self;
//  locationManager.desiredAccuracy = kCLLocationAccuracyBest;
//
//  [locationManager startUpdatingLocation];
}

- (void)displayCurrentLocationAtDefaultZoom {
  NSLog(@"displayCurrentLocationAtDefaultZoom");



  CLLocationCoordinate2D startCoord = CLLocationCoordinate2DMake(currentLocation.coordinate.latitude,
                                                                 currentLocation.coordinate.longitude);
  MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:MKCoordinateRegionMakeWithDistance(startCoord, 400000, 400000)];
  [self.mapView setRegion:adjustedRegion animated:YES];
  int radius = 100;
  [self getTruckStopDataForLatitude:currentLocation.coordinate.latitude
                       andLongitude:currentLocation.coordinate.longitude
                  withRadiusInMiles:radius];
}

- (void)centerMapOnLocation:(CLLocation *)location withZoomRadius:(double)radius {
  MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                 radius * 2.0,
                                                                 radius * 2.0);
  [self.mapView setRegion:region animated:YES];
}

- (void)centerMapOnCurrentLocation {
  const CLLocationDistance DEFAULT_RADIUS = (CLLocationDistance)milesToMeters(100.0);
  [self centerMapOnLocation:currentLocation withZoomRadius:DEFAULT_RADIUS];
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
  if ([self isOutsideContinentalUSAndCanada:mapView.centerCoordinate]) {
    if (lastKnownCenterCoordinate.latitude != 0.0 && lastKnownCenterCoordinate.longitude != 0.0) {
      [mapView setRegion:lastKnownRegion animated:YES];
    } else {
      return;
    }
  }

  int radius = (int)round([self largestMapViewSpan]);
  [self getTruckStopDataForLatitude:mapView.centerCoordinate.latitude
                       andLongitude:mapView.centerCoordinate.longitude
                  withRadiusInMiles:radius];

  lastKnownCenterCoordinate = mapView.centerCoordinate;
  lastKnownRegion = mapView.region;

  if (currentTrackingMode == kTrackingTemporarilyOff) {
    [self performSelector:@selector(centerMap) withObject:self afterDelay:5];
    currentTrackingMode = kTrackingOn;
  }
}

- (BOOL)isOutsideContinentalUSAndCanada:(CLLocationCoordinate2D)coordinate {
  // Limit user to the United States and Canada
  const double NORTHERNMOST_LATITUDE = 72.0;    // Northern edge of Alaska
  const double SOUTHERNMOST_LATITUDE = 24.0;    // Key West
  const double WESTERNMOST_LONGITUDE = -179.0;  // Aleutian islands
  const double EASTERNMOST_LONGITUDE = -50.0;   // Newfoundland

  return ((coordinate.latitude  > NORTHERNMOST_LATITUDE) ||
          (coordinate.latitude  < SOUTHERNMOST_LATITUDE) ||
          (coordinate.longitude < WESTERNMOST_LONGITUDE) ||
          (coordinate.longitude > EASTERNMOST_LONGITUDE));
}

- (double)largestMapViewSpan {
  double result;
  if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
    result = metersToMiles([self mapViewLatitudeInMeters:self.mapView]);
  } else {
    result = metersToMiles([self mapViewLongitudeInMeters:self.mapView]);
  }
  return result;
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

- (void)checkLocationAuthorizationStatus {
  if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse) {
    self.mapView.showsUserLocation = YES;
  } else {
    [locationManager requestWhenInUseAuthorization];
  }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
    [manager startUpdatingLocation];
  } else {
    UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:@"Location services off"
                                          message:@"To re-enable, please go to Settings and turn on Location Service for this app."
                                   preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    [alertController addAction:defaultAction];
    [self presentViewController:alertController animated:YES completion:nil];
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  NSLog(@"locationManager:didFailWithError:");
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  NSLog(@"didUpdateLocations");
  currentLocation = locations.lastObject;
  if (firstRun) {
    [self centerMapOnCurrentLocation];
    firstRun = NO;
  }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {

}


#pragma mark - Internet

- (void)testInternetConnection
{
  networkReachableDetector = [Reachability reachabilityWithHostname:@"www.appleiphonecell.com"];

  // Internet is reachable
  networkReachableDetector.reachableBlock = ^(Reachability *reach)
  {
    // Update the UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"Yayyy, we have the interwebs!");
    });
  };

  // Internet is not reachable
  networkReachableDetector.unreachableBlock = ^(Reachability *reach)
  {
    // Update the UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"Someone broke the internet :(");
    });
  };

  [networkReachableDetector startNotifier];
}


#pragma mark - Utility

double milesToMeters(double miles) {
  return miles * METERS_PER_MILE;
}

double metersToMiles(double meters) {
  return meters / METERS_PER_MILE;
}

@end
