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
@property (strong, nonatomic) IBOutlet UIButton* doneButton;

- (IBAction)doneButton:(id)sender;
- (void)loadURL:(NSString*)url;
- (void)shiftBelowButton;

@end
