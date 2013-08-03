//
//  TWLocApplication.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/26/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocApplication.h"
#import "TWLocAppDelegate.h"

@implementation TWLocApplication

- (BOOL)openURL:(NSURL *)url {
    NSLog(@"app URL:%@",[url absoluteString]);
    if  ([[self.delegate class] isSubclassOfClass:[TWLocAppDelegate class]]) {
        TWLocAppDelegate* appDel = self.delegate;
        if (appDel != Nil &&
            appDel.masterViewController != Nil &&
            [appDel.masterViewController openURL:url])
            return YES;
        else
            return [super openURL:url];
    } else
        return [super openURL:url];
}

@end
