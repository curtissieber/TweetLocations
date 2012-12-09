//
//  TWLoc2AppDelegate.h
//  TweetLocations2
//
//  Created by Curtis Sieber on 12/9/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TWLoc2MasterViewController.h"

@interface TWLoc2AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (retain, nonatomic) TWLoc2MasterViewController* masterViewController;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
