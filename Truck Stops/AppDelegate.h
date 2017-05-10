//
//  AppDelegate.h
//  Truck Stops
//
//  Created by Joey deVilla on 5/2/17.
//  Copyright © 2017 Joey deVilla. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;

@end

