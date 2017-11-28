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
#import "SearchViewController.h"
#import "SecureConstants.h"

@interface MapViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *trackingButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *viewSelector;
@property (weak, nonatomic) IBOutlet UISegmentedControl *resultsSelector;
@property (weak, nonatomic) IBOutlet UIButton *currentLocationButton;

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

  NSTimer *trackingDelayTimer;
  TrackingMode currentTrackingMode;

  BOOL useSearchCriteria;

  BOOL userIsReadingDetails;
  BOOL userIsBackFromSearch;
  BOOL networkInterruptionNoticeGiven;

  BOOL appHasBeenRunBefore;
  BOOL appJustStarted;

  BOOL touchDetected;

  NSUserDefaults *userDefaults;
}


#pragma mark - Setup and view events

- (void)viewDidLoad {
  [super viewDidLoad];

  appJustStarted = YES;
  appHasBeenRunBefore = ![self isFirstRun];

  touchDetected = NO;
  userIsReadingDetails = NO;
  userIsBackFromSearch = NO;
  networkInterruptionNoticeGiven = NO;
  userDefaults = [NSUserDefaults standardUserDefaults];

  [self testInternetConnection];
  [self initializeLocationManager];
  [self initializeUserControls];
  [self initializeSearch];
  [self restoreSavedTrackingMode];
}

- (void)initializeLocationManager {
  locationManager = [[CLLocationManager alloc] init];
  locationManager.delegate = self;
  [self checkLocationAuthorizationStatus];
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  [locationManager startUpdatingLocation];

  if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse) {
    [self displayLocationInterruptionNotice];
  }
}

- (void)initializeUserControls {
  // Initialize map view
  self.mapView.delegate = self;
  self.mapView.showsTraffic = YES;

  // Initialize "Standard / Satellite" selector
  self.viewSelector.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderColor = [UIColor whiteColor].CGColor;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  // Initialize current location button
  self.currentLocationButton.layer.cornerRadius = 7.0;
  self.currentLocationButton.layer.borderColor = [UIColor whiteColor].CGColor;
  self.currentLocationButton.layer.borderWidth = 4.0f;
  self.currentLocationButton.layer.masksToBounds = YES;

  // Initialize "Show all stops / Search results only" selector
  self.resultsSelector.selectedSegmentIndex = 0;
  self.resultsSelector.layer.cornerRadius = 7.0;
  self.resultsSelector.layer.borderColor = [UIColor whiteColor].CGColor;
  self.resultsSelector.layer.borderWidth = 2.0f;
  self.resultsSelector.layer.masksToBounds = YES;
}

- (void)initializeSearch {
  useSearchCriteria = NO;
  self.searchName = @"";
  self.searchCity = @"";
  self.searchState = @"";
  self.searchZip = @"";
}

- (BOOL)isFirstRun {
  if ([userDefaults objectForKey:@"appHasBeenRunBefore"] != nil) {
    [userDefaults setBool:YES forKey:@"appHasBeenRunBefore"];
    return true;
  } else {
    return false;
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}


#pragma mark - Truck stop map pins

- (void)getTruckStopDataForLatitude:(double)latitude
                       andLongitude:(double)longitude
                  withRadiusInMiles:(int)radius {
  if (latitude == 0.0 && longitude == 0.0) {
    return;
  }

  NSDictionary *headers = @{
    @"Content-Type": @"application/json",
    @"Authorization": BASIC_AUTH_STRING
  };

  NSString *formattedLat = [NSString stringWithFormat:@"%f", latitude];
  NSString *formattedLng = [NSString stringWithFormat:@"%f", longitude];
  NSLog(@"formattedLat: %@ - formattedLng: %@", formattedLat, formattedLng);
  NSDictionary *parameters = @{
    @"lat": formattedLat,
    @"lng": formattedLng
  };
  NSString *urlString = [NSString stringWithFormat:API_URL_STRING, radius];
  NSLog(@"urlString: %@", urlString);

  [[UNIRest post:^(UNISimpleRequest *request) {
    [request setUrl:urlString];
    [request setHeaders:headers];
    [request setParameters:parameters];
  }] asJsonAsync:^(UNIHTTPJsonResponse* response, NSError *error) {
    // This is the asynchronous callback block
    NSInteger code = response.code;
    NSDictionary *responseHeaders = response.headers;
    UNIJsonNode *body = response.body;
    NSData *rawBody = response.rawBody;

    if (!rawBody) {
      if (!networkInterruptionNoticeGiven) {
        [self displayNetworkInterruptionNotice];
        networkInterruptionNoticeGiven = ![self.navigationController.visibleViewController isKindOfClass:[UIAlertController class]];
      }
      return;
    }

    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:rawBody
                                                             options:kNilOptions
                                                               error:nil];
    NSArray *truckStops = jsonDict[@"truckStops"];
    if (useSearchCriteria) {
      truckStops = [self filterUsingSearchCriteria:truckStops];
    }

    NSUInteger numTruckStops = [truckStops count];

    if (numTruckStops > 0) {
      [self addTruckStops:truckStops toMapView:self.mapView];
    }
  }];
}

- (NSArray *)filterUsingSearchCriteria:(NSArray *)truckStops {
  NSLog(@"searchState: %@", self.searchState);
  NSMutableArray *searchPredicates = [NSMutableArray array];

  if (self.searchName.length > 0) {
    NSPredicate *namePredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", @"name", self.searchName];
    [searchPredicates addObject:namePredicate];
  }

  if (self.searchCity.length > 0) {
    NSPredicate *cityPredicate = [NSPredicate predicateWithFormat:@"%K = %@", @"city", self.searchCity];
    [searchPredicates addObject:cityPredicate];
  }

  if (self.searchState.length > 0) {
    NSPredicate *statePredicate = [NSPredicate predicateWithFormat:@"%K = %@", @"state", self.searchState];
    [searchPredicates addObject:statePredicate];
  }

  if (self.searchZip.length > 0) {
    NSPredicate *zipPredicate = [NSPredicate predicateWithFormat:@"%K = %@", @"zip", self.searchZip];
    [searchPredicates addObject:zipPredicate];
  }

  NSCompoundPredicate *searchPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:searchPredicates];
  return [truckStops filteredArrayUsingPredicate:searchPredicate];
}

- (void)addTruckStops:(NSArray *)truckStops toMapView:(MKMapView *)mapView {
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
      [mapView addAnnotation:point];
    });
  }
}


#pragma mark - Map positioning and rendering

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
  if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways &&
      [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse) {
    [self displayLocationInterruptionNotice];
  } else {
    [self centerMapOnCurrentLocationAtDefaultZoom];
  }
}

- (void)displayCurrentLocationAtDefaultZoom {
  CLLocationCoordinate2D startCoord = CLLocationCoordinate2DMake(currentLocation.coordinate.latitude,
                                                                 currentLocation.coordinate.longitude);
  MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:MKCoordinateRegionMakeWithDistance(startCoord, 400000, 400000)];
  [self.mapView setRegion:adjustedRegion animated:YES];
  int radius = 100;
  [self getTruckStopDataForLatitude:currentLocation.coordinate.latitude
                       andLongitude:currentLocation.coordinate.longitude
                  withRadiusInMiles:radius];
}

- (void)centerMapOnCurrentLocationAtDefaultZoom {
  const CLLocationDistance DEFAULT_RADIUS = (CLLocationDistance)milesToMeters(100.0);
  MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate,
                                                                 DEFAULT_RADIUS * 2.0,
                                                                 DEFAULT_RADIUS * 2.0);
  [self.mapView setRegion:region animated:YES];
}

- (void)centerMap {
    NSLog(@"centerMap");
    [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
}


#pragma mark - Tracking mode

- (void)restoreSavedTrackingMode {
  if ([userDefaults objectForKey:@"currentTrackingMode"] != nil) {
    TrackingMode savedTrackingMode = (TrackingMode)[userDefaults integerForKey:@"currentTrackingMode"];
    if (savedTrackingMode == kTrackingOn) {
      [self turnTrackingModeOn];
    } else {
      [self turnTrackingModeOff];
    }
  } else {
    [self turnTrackingModeOn];
  }
}

- (IBAction)trackingButtonTapped:(UIBarButtonItem *)sender {
  if (currentTrackingMode != kTrackingOn) {
    [self turnTrackingModeOn];
  } else {
    [self turnTrackingModeOff];
  }
}

- (void)turnTrackingModeOn {
  currentTrackingMode = kTrackingOn;
  [userDefaults setInteger:currentTrackingMode forKey:@"currentTrackingMode"];
  userIsReadingDetails = NO;
  userIsBackFromSearch = NO;
  [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
  [self.trackingButton setTitle:@"Tracking on"];
  [self cancelTrackingDelayTimer];
}

- (void)turnTrackingModeOff {
  currentTrackingMode = kTrackingOff;
  [userDefaults setInteger:currentTrackingMode forKey:@"currentTrackingMode"];
  [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:YES];
  [self.trackingButton setTitle:@"Tracking off"];
  [self cancelTrackingDelayTimer];
}

- (void)startTrackingDelayTimer:(double)delay {
  [self cancelTrackingDelayTimer];
  trackingDelayTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                        target:self
                                                      selector:@selector(turnTrackingModeOn)
                                                      userInfo:nil
                                                       repeats:NO];
}

- (void)cancelTrackingDelayTimer {
  if (trackingDelayTimer) {
    [trackingDelayTimer invalidate];
    trackingDelayTimer = nil;
  }
}

- (void)centerMapAndTurnTrackingOn {
  [self centerMap];
  currentTrackingMode = kTrackingOn;
}


#pragma mark - Search

- (void)changeSearchMode {
  userIsBackFromSearch = YES;
  [self.resultsSelector setSelectedSegmentIndex:1];
  [self userChangedSearchMode:self.resultsSelector];

  if (currentTrackingMode != kTrackingOff) {
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
    [self startTrackingDelayTimer:30];
  }
}

- (IBAction)userChangedSearchMode:(UISegmentedControl *)sender {
  switch (sender.selectedSegmentIndex) {
    case 0:
      useSearchCriteria = NO;
      break;
    case 1:
      useSearchCriteria = YES;
      [self.mapView removeAnnotations:self.mapView.annotations];
      break;
    default:
      useSearchCriteria = NO;
      break;
  }

  int radius = (int)round([self largestMapViewSpan]);
  [self getTruckStopDataForLatitude:self.mapView.centerCoordinate.latitude
                       andLongitude:self.mapView.centerCoordinate.longitude
                  withRadiusInMiles:radius];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqual: @"SearchParms"]) {
    SearchViewController *searchViewController = [segue destinationViewController];
    searchViewController.delegate = self;
  }
}


#pragma mark - Touch response

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  NSLog(@"Touches began");
  touchDetected = YES;
  lastKnownRegion = self.mapView.region;

  if (currentTrackingMode == kTrackingOn) {
    currentTrackingMode = kTrackingTemporarilyOff;
    [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:YES];
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  NSLog(@"Touches ended");
  touchDetected = NO;
  if (currentTrackingMode != kTrackingOff) {
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
    if (!userIsBackFromSearch) {
      int delay = userIsReadingDetails ? 15 : 5;
      [self startTrackingDelayTimer:delay];
    }
  }
}


#pragma mark - Map view methods

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

  if (touchDetected) {
    touchDetected = NO;
    if (currentTrackingMode != kTrackingOff) {
      self.mapView.userTrackingMode = MKUserTrackingModeNone;
      [self startTrackingDelayTimer:5];
    }
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

  // Get latitude in meters
  CLLocation *topEdgeCenter = [[CLLocation alloc] initWithLatitude:(center.latitude - span.latitudeDelta * 0.5) longitude:center.longitude];
  CLLocation *bottomEdgeCenter = [[CLLocation alloc] initWithLatitude:(center.latitude + span.latitudeDelta * 0.5) longitude:center.longitude];
  return [topEdgeCenter distanceFromLocation:bottomEdgeCenter];
}

- (int)mapViewLongitudeInMeters:(MKMapView *)mapView {
  MKCoordinateSpan span = mapView.region.span;
  CLLocationCoordinate2D center = mapView.region.center;

  // Get longitude in meters
  CLLocation *leftEdgeCenter = [[CLLocation alloc] initWithLatitude:center.latitude longitude:(center.longitude - span.longitudeDelta * 0.5)];
  CLLocation *rightEdgeCenter = [[CLLocation alloc] initWithLatitude:center.latitude longitude:(center.longitude + span.longitudeDelta * 0.5)];
  return [leftEdgeCenter distanceFromLocation:rightEdgeCenter];
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

    NSString *name = annotation.title;
    NSString *baseName;
    if ([name hasPrefix:@"Pilot"]) {
      baseName = @"pilot";
    } else if ([name hasPrefix:@"Flying J"]) {
      baseName = @"flying j";
    } else if ([name hasPrefix:@"Love"]) {
      baseName = @"loves";
    } else if ([name hasPrefix:@"Travel"]) {
      baseName = @"travel centers";
    } else {
      baseName = @"truck";
    }
    NSString *pinImageName = [NSString stringWithFormat:@"%@ pin", baseName];
    [annotationView setImage:[UIImage imageNamed:pinImageName]];

    CLLocationCoordinate2D annotationCoordinate = annotationView.annotation.coordinate;
    CLLocation *annotationLocation = [[CLLocation alloc] initWithLatitude:annotationCoordinate.latitude
                                                                longitude:annotationCoordinate.longitude];
    int distance = (int)round(metersToMiles([currentLocation distanceFromLocation:annotationLocation]));

    UIImageView *detailImageView;
    NSString *logoName = [NSString stringWithFormat:@"%@ logo", baseName];
    detailImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:logoName]];
    annotationView.leftCalloutAccessoryView = detailImageView;

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

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
  NSLog(@"didSelectAnnotationView");
  if (currentTrackingMode != kTrackingOff) {
    userIsReadingDetails = YES;
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
  }
}


#pragma mark - Location Manager

- (void)checkLocationAuthorizationStatus {
  if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse ||
      [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
    self.mapView.showsUserLocation = YES;
  } else {
    [locationManager requestWhenInUseAuthorization];
  }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
    [manager startUpdatingLocation];
  } else if (appHasBeenRunBefore && !appJustStarted) {
    [self displayNetworkInterruptionNotice];
  }
}

- (void)displayLocationInterruptionNotice {
  UIAlertController *alertController =
  [UIAlertController alertControllerWithTitle:@"Location services off"
                                      message:@"This app can still display truck stops, but can’t display your current location with location services disabled.\nTo re-enable them, please go to Settings and turn on Location Service for this app."
                               preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) {}];
  [alertController addAction:defaultAction];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  NSLog(@"locationManager:didFailWithError:");
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  NSLog(@"locationManager:didUpdateLocations");
  currentLocation = locations.lastObject;
  if (appJustStarted) {
    [self centerMapOnCurrentLocationAtDefaultZoom];
    [self getTruckStopDataForLatitude:currentLocation.coordinate.longitude
                         andLongitude:currentLocation.coordinate.latitude
                    withRadiusInMiles:100.0];
    appJustStarted = NO;
  }
}


#pragma mark - Internet connection

- (void)testInternetConnection {
  networkReachableDetector = [Reachability reachabilityWithHostname:@"www.appleiphonecell.com"];

  // It’s a bad idea to use “self” inside a block,
  // so let’s create references to self that
  // we’re certain will not be retained.
  __block MapViewController *blockSafeSelf = self;
  __block BOOL noticeGiven = networkInterruptionNoticeGiven;

  // Internet is reachable
  networkReachableDetector.reachableBlock = ^(Reachability *reach)
  {
    // Update the UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"Connected!");
    });
    networkInterruptionNoticeGiven = NO;
  };

  // Internet is not reachable
  networkReachableDetector.unreachableBlock = ^(Reachability *reach)
  {
    if (!noticeGiven) {
      // Update the UI on the main thread
      dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Connection down!");
        [blockSafeSelf displayNetworkInterruptionNotice];
      });

      // Is another alert is currently being shown, the “No connection” alert will be blocked,
      // so *DON’T* mark it down as having been shown.
      NSLog(@"networkInterruptionNoticeGiven: %d", [blockSafeSelf.navigationController.visibleViewController isKindOfClass:[UIAlertController class]]);
      networkInterruptionNoticeGiven = ![blockSafeSelf.navigationController.visibleViewController isKindOfClass:[UIAlertController class]];
    }
  };

  [networkReachableDetector startNotifier];
}

- (void)displayNetworkInterruptionNotice {
  UIAlertController *alertController =
  [UIAlertController alertControllerWithTitle:@"Network connection lost"
                                      message:@"This app can’t display truck stop information until the network connection is restored."
                               preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) {}];
  [alertController addAction:defaultAction];
  [self presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - Conversion functions

double milesToMeters(double miles) {
  return miles * METERS_PER_MILE;
}

double metersToMiles(double meters) {
  return meters / METERS_PER_MILE;
}

@end
