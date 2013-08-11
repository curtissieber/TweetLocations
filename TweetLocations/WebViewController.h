//
//  WebViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/11/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController <UIWebViewDelegate>

@property (retain, nonatomic) NSString* theURL;
@property (strong, nonatomic) IBOutlet UIWebView* webView;

- (IBAction)doneButton:(id)sender;
- (void)grabMovie:(NSString*)movieURL;

@end
