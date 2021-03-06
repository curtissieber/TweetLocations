//
//  WebViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/11/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import "WebViewController.h"

@interface WebViewController ()

@end

@implementation WebViewController

- (void)loadURL:(NSString*)url
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSURLRequest* urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [_webView loadRequest:urlRequest];
        [_webView reload];
        NSLog(@"loadrequest for %@", urlRequest);
    }];
}

- (void)shiftBelowButton
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        CGRect wframe = [_webView frame];
        CGRect bframe = [_doneButton frame];
        wframe.size.height -= bframe.origin.y;
        wframe.origin.y += bframe.origin.y;
        [_webView setFrame:wframe];
    }];
}

- (IBAction)doneButton:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:Nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [_webView setDelegate:self];
    NSLog(@"done with viewDidLoad");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark WebViewDelegate
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"didFailLoadWithError %@", error);
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSLog(@"webViewDidFinishLoad");
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"webViewDidStartLoad");
}

@end
