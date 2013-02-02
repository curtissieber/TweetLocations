//
//  TWLocAccountViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 1/19/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TWLocMasterViewController.h"
#import "Tweet.h"

@interface TWLocAccountViewController : UITableViewController

@property (retain, nonatomic) TWLocMasterViewController* master;
@property (retain, nonatomic) NSArray* tweets;

@end
