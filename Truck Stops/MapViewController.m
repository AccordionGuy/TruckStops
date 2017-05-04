//
//  ViewController.m
//  Truck Stops
//
//  Created by Joey deVilla on 5/2/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import "MapViewController.h"
#import "UNIRest.h"

@interface MapViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *viewSelector;
@property (weak, nonatomic) IBOutlet UIButton *currentLocationButton;

@end

typedef enum {
  kTrackingOff,
  kTrackingTemporarilyOff,
  kTrackingOn
} TrackingMode;

@implementation MapViewController {
  CLLocationManager *locationManager;

  CLLocation *currentLocation;

  TrackingMode currentTrackingMode;

  bool isInTrackingMode;
  bool userIsReadingDetails;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.mapView.delegate = self;
  [self.mapView setUserTrackingMode:MKUserTrackingModeFollow];

  // Initialize segmented control
  self.viewSelector.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderColor = [UIColor whiteColor].CGColor;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  // Initialize current location button
  self.currentLocationButton.layer.cornerRadius = 7.0;
  self.viewSelector.layer.borderWidth = 2.0f;
  self.viewSelector.layer.masksToBounds = YES;

  // TODO: Get this values from UserDefaukts
  currentTrackingMode = kTrackingOn;

  userIsReadingDetails = NO;

  locationManager = [[CLLocationManager alloc] init];
  locationManager.delegate = self;
  // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
  if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
    [locationManager requestWhenInUseAuthorization];
  }
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  [locationManager startUpdatingLocation];

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
      self.mapView.mapType = MKMapTypeSatellite;
      break;
    default:
      self.mapView.mapType = MKMapTypeStandard;
      break;
  }
}

- (IBAction)currentLocationButtonTapped:(UIButton *)sender {
  [locationManager startUpdatingLocation];

  // [self displayCurrentLocationAtDefaultZoom];
  [self getTruckStopDataForLatitude:currentLocation.coordinate.latitude
                       andLongitude:currentLocation.coordinate.longitude
                         withRadius:100.0];
}

- (void)getTruckStopDataForLatitude:(double)latitude
                       andLongitude:(double)longitude
                         withRadius:(double)radiusInMiles{
  NSDictionary *headers = @{
    @"Content-Type": @"application/json",
    @"Authorization": @"Basic amNhdGFsYW5AdHJhbnNmbG8uY29tOnJMVGR6WmdVTVBYbytNaUp6RlIxTStjNmI1VUI4MnFYcEVKQzlhVnFWOEF5bUhaQzdIcjVZc3lUMitPTS9paU8="
  };
  NSDictionary *parameters = @{
    @"lat": [NSString stringWithFormat:@"%f", latitude],
    @"lng": [NSString stringWithFormat:@"%f", longitude]
  };

  NSString *urlString = [NSString stringWithFormat:@"http://webapp.transflodev.com/svc1.transflomobile.com/api/v3/stations/%f", radiusInMiles];
  UNIHTTPJsonResponse *response = [[UNIRest post:^(UNISimpleRequest *request) {
    [request setUrl:urlString];
    [request setHeaders:headers];
    [request setParameters:parameters];
  }] asJson];

  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response.rawBody
                                                       options:kNilOptions
                                                         error:nil];
  NSLog(@"Response status: %ld\n%@", (long) response.code, json);
}


- (void)getCurrentLocation {
  locationManager.delegate = self;
  locationManager.desiredAccuracy = kCLLocationAccuracyBest;

  [locationManager startUpdatingLocation];
}

- (void)displayCurrentLocationAtDefaultZoom {
  const double DEFAULT_MAP_SIZE = 100;

  MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, milesToMeters(DEFAULT_MAP_SIZE), milesToMeters(DEFAULT_MAP_SIZE));
  [self.mapView setRegion:region animated:YES];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  NSLog(@"Touches began");
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

// Map position or zoom level changed
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
  NSLog(@"mapView:regionDidChangeAnimated:");

  if (currentTrackingMode == kTrackingTemporarilyOff) {
    [self performSelector:@selector(centerMap) withObject:self afterDelay:5];
    currentTrackingMode = kTrackingOn;
  }
}

- (void)centerMap {
  NSLog(@"centerMap");
  [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
  MKAnnotationView *pin = (MKAnnotationView *) [self.mapView dequeueReusableAnnotationViewWithIdentifier: @"VoteSpotPin"];
  if (pin == nil)
  {
    pin = [[MKAnnotationView alloc] initWithAnnotation: annotation reuseIdentifier: @"TestPin"] ;
  }
  else
  {
    pin.annotation = annotation;
  }

  [pin setImage:[UIImage imageNamed:@"truck pin.png"]];
  pin.canShowCallout = YES;
  pin.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
  return pin;
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
  return miles * 1609.34;
}

@end

