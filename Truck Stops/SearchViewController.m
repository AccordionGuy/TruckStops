//
//  SearchViewController.m
//  Truck Stops
//
//  Created by Joey deVilla on 5/25/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import "SearchViewController.h"

@interface SearchViewController ()
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *cityTextField;
@property (weak, nonatomic) IBOutlet UIPickerView *statePicker;
@property (weak, nonatomic) IBOutlet UITextField *zipTextField;

@end

@implementation SearchViewController {
  MapViewController *mapViewController;
  NSArray *stateAbbreviations;
  NSArray *stateNames;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  stateAbbreviations = @[
    @"",
    @"AL",
    @"AK",
    @"AZ",
    @"AR",
    @"CA",
    @"CO",
    @"CT",
    @"DE",
    @"FL",
    @"GA",
    @"HI",
    @"ID",
    @"IL",
    @"IN",
    @"IA",
    @"KS",
    @"KY",
    @"LA",
    @"ME",
    @"MD",
    @"MA",
    @"MI",
    @"MN",
    @"MS",
    @"MO",
    @"MT",
    @"NE",
    @"NV",
    @"NH",
    @"NJ",
    @"NM",
    @"NY",
    @"NC",
    @"ND",
    @"OH",
    @"OK",
    @"OR",
    @"PA",
    @"RI",
    @"SC",
    @"SD",
    @"TN",
    @"TX",
    @"UT",
    @"VT",
    @"VA",
    @"WA",
    @"WV",
    @"WI",
    @"WY"
  ];
  stateNames = @[
    @"Any state",
    @"Alabama",
    @"Alaska",
    @"Arizona",
    @"Arkansas",
    @"California",
    @"Colorado",
    @"Connecticut",
    @"Delaware",
    @"Florida",
    @"Georgia",
    @"Hawaii",
    @"Idaho",
    @"Illinois",
    @"Indiana",
    @"Iowa",
    @"Kansas",
    @"Kentucky",
    @"Louisiana",
    @"Maine",
    @"Maryland",
    @"Massachusetts",
    @"Michigan",
    @"Minnesota",
    @"Mississippi",
    @"Missouri",
    @"Montana",
    @"Nebraska",
    @"Nevada",
    @"New Hampshire",
    @"New Jersey",
    @"New Mexico",
    @"New York",
    @"North Carolina",
    @"North Dakota",
    @"Ohio",
    @"Oklahoma",
    @"Oregon",
    @"Pennsylvania",
    @"Rhode Island",
    @"South Carolina",
    @"South Dakota",
    @"Tennessee",
    @"Texas",
    @"Utah",
    @"Vermont",
    @"Virginia",
    @"Washington",
    @"West Virginia",
    @"Wisconsin",
    @"Wyoming"
  ];
  self.statePicker.dataSource = self;
  self.statePicker.delegate = self;

  self.nameTextField.text = self.delegate.searchName;
  self.cityTextField.text = self.delegate.searchCity;
  self.zipTextField.text = self.delegate.searchZip;

  NSInteger row = [stateAbbreviations indexOfObject:self.delegate.searchState];
  [self.statePicker selectRow:row inComponent:0 animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
  self.delegate.searchName = [self.nameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  self.delegate.searchCity = [self.cityTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  self.delegate.searchZip  = [self.zipTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  NSInteger row = [self.statePicker selectedRowInComponent:0];
  self.delegate.searchState = stateAbbreviations[row];

  [self.delegate changeSearchMode];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)clearSearchCriteriaButtonTapped:(UIButton *)sender {
  self.nameTextField.text = @"";
  self.cityTextField.text = @"";
  self.zipTextField.text = @"";

  [self.statePicker selectRow:0 inComponent:0 animated:YES];
}


#pragma mark - State picker delegate methods

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
  return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
  return stateNames.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
  return stateNames[row];
}

@end
