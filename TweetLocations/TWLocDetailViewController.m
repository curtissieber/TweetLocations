//
//  TWLocDetailViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocDetailViewController.h"
#import "TWLocMasterViewController.h"
#import "PhotoGetter.h"
#import "URLFetcher.h"
#import <ImageIO/CGImageDestination.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface TWLocDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation TWLocDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if ( newDetailItem != Nil &&
        [[newDetailItem class] isSubclassOfClass:[Tweet class]] /*&&
        _detailItem != newDetailItem*/) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
        [_detailItem setHasBeenRead:[NSNumber numberWithBool:YES]];
        NSManagedObjectContext *context = [_master.fetchedResultsController managedObjectContext];
        [context processPendingChanges];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView
{
    @try {
        // Update the user interface for the detail item.
        if (self.detailItem) {
            [_activityView startAnimating];
            Tweet *tweet = self.detailItem;
            self.title = [tweet timestamp];
            
            NSMutableString* detail = [[NSMutableString alloc] initWithFormat:@"[%@]:%@\n",
                                       [tweet username], [tweet tweet] ];
            if ([[tweet url] length] > 4)
                [detail appendFormat:@" [%@]", [tweet url]];
            double latitude = [[tweet latitude] doubleValue];
            double longitude = [[tweet longitude] doubleValue];
            if (latitude > -900 && longitude > -900)
                [detail appendFormat:@" [%0.1lf,%0.1lf]",latitude,longitude];
            [detail appendFormat:@" %@",[tweet timestamp]];
            
            [self.detailDescriptionLabel setText:detail];
            if ([[tweet hasBeenRead] boolValue] == YES)
                [self.detailDescriptionLabel setBackgroundColor:[UIColor lightGrayColor]];
            else
                [self.detailDescriptionLabel setBackgroundColor:[UIColor clearColor]];
            [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
            
            NSMutableString* bigDetail = [[NSMutableString alloc] initWithFormat:@"%@\n[%@]",
                                          [tweet tweet], [tweet username]];
            [self.bigLabel setText:bigDetail];
            
            if (latitude > -900 && longitude > -900) {
                [self resizeForMap];
                [self displayMap:[tweet tweet] lat:latitude lon:longitude];
            } else {
                [self resizeWithoutMap];
                [self.mapView setHidden:YES];
            }
            
            [self.imageView setImage:Nil];
            [self.textView setText:Nil];
            
            NSData* imageData = [_master imageData:[tweet url]];
            if (imageData != Nil) {
                //[self.textView setText:[_detailItem origHTML]];
                NSLog(@"using cached data for %@",[tweet url]);
                thisImageData = imageData;
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                                
                [PhotoGetter setupImage:image
                                  iview:self.imageView
                                  sview:self.scrollView
                                 button:self.sizeButton];
                                                
                if (latitude > -900 && longitude > -900) {
                    [self resizeForMap];
                    [self displayMap:[tweet timestamp]
                                 lat:latitude
                                 lon:longitude];
                } 
                
                [self.scrollView setHidden:NO];
                [_activityView stopAnimating];
            } else if ([[tweet url] length] > 4) {
                [[self sizeButton] setTitle:@"no pic" forState:UIControlStateNormal];
                [[self sizeButton] setTitle:@"no pic" forState:UIControlStateHighlighted];
                [[self sizeButton] setTitle:@"no pic" forState:UIControlStateSelected];
                /*if ([_detailItem origHTML] != Nil) {
                    [_textView setText:[_detailItem origHTML]];
                    [_activityView stopAnimating];
                } else*/
                    [self handleURL:[tweet url]];
            } else {
                [self.scrollView setHidden:YES];
                NSMutableString* nonono = [[NSMutableString alloc]initWithCapacity:500];
                for (int i=0; i < 5; i++)
                    [nonono appendString:@"NO URL NO URL NO URL NO URL\n"];
                [self.textView setText:nonono];
                [[self sizeButton] setTitle:@"no url" forState:UIControlStateNormal];
                [[self sizeButton] setTitle:@"no url" forState:UIControlStateHighlighted];
                [[self sizeButton] setTitle:@"no url" forState:UIControlStateSelected];
                [_activityView stopAnimating];
            }
        }
    } @catch (NSException *eee) {
        [_activityView stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)resizeForMap
{
    if (self.mapView.hidden == NO)
        return;
    CGRect totalFrame = [[self view] frame];
    CGRect detailFrame = [_detailDescriptionLabel frame];
    CGRect mapFrame = [_mapView frame];
    CGRect textFrame = [_textView frame];
    CGRect scrollFrame = [_scrollView frame];
    CGRect bigFrame = [_bigLabel frame];
    
    // detail sits at the bottom
    detailFrame.origin.y = totalFrame.size.height - detailFrame.size.height;
    // map sits above the detail
    mapFrame.origin.y = detailFrame.origin.y - mapFrame.size.height;
    // big label sits above the map
    bigFrame.origin.y = mapFrame.origin.y - bigFrame.size.height;
    //scroll sits above the map and resizes for such
    scrollFrame.size.height = mapFrame.origin.y;
    scrollFrame.origin.y = 0;
    //text is the same as scrollframe
    textFrame.size.height = mapFrame.origin.y;
    textFrame.origin.y = 0;
    
    [_bigLabel setFrame:bigFrame];
    [_scrollView setFrame:scrollFrame];
    [_textView setFrame:textFrame];
    [_mapView setFrame:mapFrame];
    [_detailDescriptionLabel setFrame:detailFrame];
    
    /*float height = [self.mapView frame].size.height;
    CGRect scrollFrame = [self.scrollView frame];
    scrollFrame.size.height -= height;
    [self.scrollView setFrame:scrollFrame];
    CGRect textFrame = [self.bigLabel frame];
    textFrame.origin.y = scrollFrame.origin.y + scrollFrame.size.height - textFrame.size.height;
    [self.bigLabel setFrame:textFrame];*/
}
- (void)resizeWithoutMap
{
    if (self.mapView.hidden == YES)
        return;
    CGRect totalFrame = [[self view] frame];
    CGRect detailFrame = [_detailDescriptionLabel frame];
    CGRect mapFrame = [_mapView frame];
    CGRect textFrame = [_textView frame];
    CGRect scrollFrame = [_scrollView frame];
    CGRect bigFrame = [_bigLabel frame];
    
    // detail sits at the bottom
    detailFrame.origin.y = totalFrame.size.height - detailFrame.size.height;
    // map sits above the detail, but is hidden
    mapFrame.origin.y = detailFrame.origin.y - mapFrame.size.height;
    // big label sits above the detail
    bigFrame.origin.y = detailFrame.origin.y - bigFrame.size.height;
    //scroll sits above the detail and resizes for such
    scrollFrame.size.height = detailFrame.origin.y;
    scrollFrame.origin.y = 0;
    //text is the same as scrollframe
    textFrame.size.height = detailFrame.origin.y;
    textFrame.origin.y = 0;
    
    [_bigLabel setFrame:bigFrame];
    [_scrollView setFrame:scrollFrame];
    [_textView setFrame:textFrame];
    [_mapView setFrame:mapFrame];
    [_detailDescriptionLabel setFrame:detailFrame];
    
    /*float height = [self.mapView frame].size.height;
    CGRect scrollFrame = [self.scrollView frame];
    scrollFrame.size.height += height;
    [self.scrollView setFrame:scrollFrame];
    CGRect textFrame = [self.bigLabel frame];
    textFrame.origin.y = scrollFrame.origin.y + scrollFrame.size.height - textFrame.size.height;
    [self.bigLabel setFrame:textFrame];*/
}

- (void)handleURL:(NSString*)url
{
    if ([TWLocDetailViewController imageExtension:url]) {
        [self openURL:[NSURL URLWithString:url]];
        return;
    }
    
    URLFetcher* fetcher = [[URLFetcher alloc] init];
    [fetcher fetch:url urlCallback:^(NSMutableString *html) {
        if (html != Nil) {
            [self.textView setText:[[self getURLs:html] componentsJoinedByString:@"\n\n"]];
            [self.scrollView setHidden:YES];
            [self findJPG:html theUrlStr:url];
        } else {
            [self.textView setText:@"CONNECTION FAILED"];
        }
        [_activityView stopAnimating];
    }];
}

#pragma mark image

// will get hit when the user chooses a URL from the text view
// should load the image
-(BOOL)openURL:(NSURL *)url
{
    Tweet* originalTweet = _detailItem;
    NSString* urlStr = [url description];
    if (![TWLocDetailViewController imageExtension:urlStr]) {
        [self handleURL:urlStr]; // just grab the URL flat-up
    }
    
    [_activityView startAnimating];
    PhotoGetter *getter = [[PhotoGetter alloc] init];
    [getter setIsRetinaDisplay:isRetinaDisplay];
    [getter getPhoto:url
                into:self.imageView
              scroll:self.scrollView
           sizelabel:self.sizeButton
            callback:^(float latitude, float longitude, NSString* timestamp, NSData* data) {
                if (data == Nil) {
                    [_activityView stopAnimating];
                    return;
                }
                thisImageData = data;
                [self.scrollView setHidden:NO];
                if (_master != Nil) {
                    [_master imageData:data forURL:urlStr];
                }
                if (originalTweet != _detailItem) { // oops we moved !!
                    [_activityView stopAnimating];
                    return;
                }
                if (latitude > -900) {
                    [self resizeForMap];
                    [self displayMap:timestamp lat:latitude lon:longitude];
                    [_detailItem setLocationFromPic:[NSNumber numberWithBool:YES]];
                    [_detailItem setLatitude:[NSNumber numberWithDouble:latitude]];
                    [_detailItem setLongitude:[NSNumber numberWithDouble:longitude]];
                }
                [_detailItem setUrl:urlStr];
                NSManagedObjectContext *context = [_master.fetchedResultsController managedObjectContext];
                [context processPendingChanges];
                
                [_activityView stopAnimating];
            }];
    return YES;
}

+ (BOOL)imageExtension:(NSString*)urlStr
{
    NSRange checkRange = NSMakeRange([urlStr length]-5, 5);
    if ([urlStr compare:@".jpeg" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    checkRange = NSMakeRange([urlStr length]-4, 4);
    if ([urlStr compare:@".jpg" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".png" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".gif" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    //NSLog(@"No");
    return NO;
}

- (NSMutableArray*)getURLs:(NSString*)html
{
    return [TWLocDetailViewController staticGetURLs:html];
}

+ (NSMutableArray*)staticGetURLs:(NSString*)html
{
    //NSLog(@"regex search started");
    /*NSError __autoreleasing *err = [[NSError alloc] init];
    NSRegularExpression* regex = [[NSRegularExpression alloc]
                                  initWithPattern:@"\"http:[^\"]*\""
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&err];
    NSArray* matches = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];*/
    NSMutableArray* strResults = [[NSMutableArray alloc] initWithCapacity:10];
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:Nil];
    [detector enumerateMatchesInString:html options:0 range:NSMakeRange(0, [html length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if ([result resultType] == NSTextCheckingTypeLink) {
            NSString* urlStr = [[result URL] absoluteString];
            if ([urlStr compare:@"tel:" options:0 range:NSMakeRange(0, 4)] != NSOrderedSame)
                [strResults addObject:urlStr];
        }
    }];
    return strResults;
    
    NSArray* matches = [detector matchesInString:html options:0 range:NSMakeRange(0, [html length])];
        
    //NSLog(@"got %d link matches", [matches count]);
    
    NSEnumerator* e = [matches objectEnumerator];
    NSTextCheckingResult* current;
    
    while ((current = [e nextObject]) != Nil) {
        if ([current resultType] == NSTextCheckingTypeLink) {
            /*NSRange insideQuotes = NSMakeRange([current range].location+1, [current range].length-2);
            NSMutableString* truncated = [[NSMutableString alloc]
                                          initWithString:[html substringWithRange:insideQuotes]];
            [truncated replaceOccurrencesOfString:@"\\/" withString:@"/" options:NSLiteralSearch range:NSMakeRange(0, [truncated length])];*/
            [strResults addObject:[[current URL] absoluteString]];
        }
    }
    //NSLog(@"giving %d links",[strResults count]);
    
    return strResults;
}

- (void)findJPG:(NSMutableString*)html theUrlStr:(NSString*)url
{
    NSString* replace = [TWLocDetailViewController staticFindJPG:html theUrlStr:url];
    //[_detailItem setOrigHTML:html];
    if (replace != Nil) {
        if ([TWLocDetailViewController imageExtension:replace])
            [self openURL:[NSURL URLWithString:replace]];
        else 
            [self handleURL:replace];
    } else {
        [self.textView setText:html];
        [_activityView stopAnimating];
    }
}

+ (NSString*)staticFindJPG:(NSMutableString*)html theUrlStr:(NSString*)url
{
    NSMutableArray* htmlResults = [self staticGetURLs:html];
    NSEnumerator* e = [htmlResults objectEnumerator];
    NSString* current;
    NSMutableArray* strResults = [[NSMutableArray alloc] initWithCapacity:10];
    
    while ((current = [e nextObject]) != Nil) {
        if ([TWLocDetailViewController imageExtension:current])
            [strResults addObject:current];
        else if ([current rangeOfString:@".tumblr.com/image/"].location != NSNotFound)
            [strResults addObject:current];
    }
    //NSLog(@"only %d links are images",[strResults count]);
    
    [strResults sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSMutableString* str1 = [[NSMutableString alloc] initWithString:obj1];
        NSMutableString* str2 = [[NSMutableString alloc] initWithString:obj2];
        if ([str1 rangeOfString:@".tumblr.com/image/"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@".tumblr.com/image/"].location != NSNotFound)
            return NSOrderedDescending;
        [str1 deleteCharactersInRange:NSMakeRange([str1 length]-4,4)];
        [str2 deleteCharactersInRange:NSMakeRange([str2 length]-4,4)];
        
        NSRange dropChars = NSMakeRange(0,[str1 length]);
        while (isdigit([str1 characterAtIndex:(dropChars.location+dropChars.length-1)]))
            dropChars.length--;
        [str1 deleteCharactersInRange:dropChars];
        dropChars = NSMakeRange(0,[str2 length]);
        while (isdigit([str2 characterAtIndex:(dropChars.location+dropChars.length-1)]))
            dropChars.length--;
        [str2 deleteCharactersInRange:dropChars];
        
        if ([str1 length] == 0 && [str2 length] > 0)
            return NSOrderedDescending; //NSOrderedAscending; but reverse it
        if ([str2 length] == 0 && [str1 length] > 0)
            return NSOrderedAscending; //NSOrderedDescending; but reverse it
        if ([str1 length] == 0 && [str2 length] == 0)
            return NSOrderedSame;
        
        if ([str1 integerValue] > [str2 integerValue])
            return NSOrderedAscending; //NSOrderedDescending; but reverse it
        if ([str1 integerValue] < [str2 integerValue])
            return NSOrderedDescending; //NSOrderedAscending; but reverse it
        
        return NSOrderedSame;
    }];
    
    NSString* str;
    if ([strResults count] > 0)
        e = [strResults objectEnumerator];
    else
        e = [htmlResults objectEnumerator];
    NSString* replaceStr = [URLFetcher canReplaceURL:url enumerator:e];

    NSMutableString* allMatches = [[NSMutableString alloc] initWithCapacity:256];
    
    e = [strResults objectEnumerator];
    while ((str = [e nextObject]) != Nil) {
        [allMatches appendString:str];
        [allMatches appendString:@"\n"];
        [allMatches appendString:@"\n"];
    }
    [allMatches appendString:@"FULL URL LISTING\n\n"];
    e = [htmlResults objectEnumerator];
    while ((str = [e nextObject]) != Nil) {
        [allMatches appendString:str];
        [allMatches appendString:@"\n"];
        [allMatches appendString:@"\n"];
    }

    [html setString:allMatches];
    if (replaceStr != Nil) {
        return replaceStr;
    }
    return Nil;
}


- (void)displayMap:(NSString*)text lat:(double)latitude lon:(double)longitude
{
    @try {
        [self.mapView setHidden:NO];

        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latitude, longitude);
        MKCoordinateRegion region = MKCoordinateRegionMake(coord,
                                                           MKCoordinateSpanMake(0.1, 0.1));
        
        NSArray* annotations = [self.mapView annotations];
        [self.mapView removeAnnotations:annotations];
        
        MKPointAnnotation* point = [[MKPointAnnotation alloc] init];
        point.coordinate = coord;
        point.title = text;
        [self.mapView addAnnotation:point];
        
        [self.mapView setCenterCoordinate:coord animated:YES];
        [self.mapView setRegion:region animated:YES];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

#pragma mark SaveImage
- (IBAction)doSave:(id)sender
{
    @try {
        if (self.master == Nil)
            return;
        NSData* imageData = thisImageData;
        if (imageData == Nil)
            imageData = [self.master imageData:[_detailItem url]];
        if (imageData != Nil) {
            ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
            [library writeImageDataToSavedPhotosAlbum:imageData metadata:Nil
                                      completionBlock:
                 ^(NSURL *assetURL, NSError *error) {
                     NSLog(@"Image write error=%@",error);
                     NSLog(@"Image write url=%@",[assetURL description]);
                     if (error != NULL)
                     {
                         UIAlertView *alert =
                         [[UIAlertView alloc] initWithTitle:@"Save To Camera Roll FAILED"
                                                    message:@"Oh my! What a disgrace!"
                                                   delegate:self
                                          cancelButtonTitle:@"Yah, Whatever"
                                          otherButtonTitles: nil];
                         [alert show];
                         
                     }
                     else  // No errors
                     {
                         // Show message image successfully saved
                         UIAlertView *alert =
                         [[UIAlertView alloc] initWithTitle:@"Save To Camera Roll SUCCESS"
                                                    message:@"Wheeeeeee! YAY!"
                                                   delegate:self
                                          cancelButtonTitle:@"Oh, that was FINE!"
                                          otherButtonTitles: nil];
                         [alert show];
                     }
                     
                 }];
            /*UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:imageData], self,
                                           @selector(image:didFinishSavingWithError:contextInfo:), nil);*/
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
// gets called at the end of the save action
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
  contextInfo:(void *)contextInfo
{
    // Was there an error?
    if (error != NULL)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Save To Camera Roll FAILED"
                                                        message:@"Oh my! What a disgrace!"
                                                       delegate:self
                                              cancelButtonTitle:@"Yah, Whatever"
                                              otherButtonTitles: nil];
        [alert show];
        
    }
    else  // No errors
    {
        // Show message image successfully saved
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Save To Camera Roll SUCCESS"
                                                        message:@"Wheeeeeee! YAY!"
                                                       delegate:self
                                              cancelButtonTitle:@"Oh, that was FINE!"
                                              otherButtonTitles: nil];
        [alert show];
    }
}

#pragma mark scrollview items

- (UIView *) viewForZoomingInScrollView: (UIScrollView *) scrollView
{
    return self.imageView;
}

#pragma mark view items

static bool isRetinaDisplay = NO;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
        ([UIScreen mainScreen].scale == 2.0)) {
        isRetinaDisplay = YES; // Retina display
    } else {
        isRetinaDisplay = NO; // non-Retina display
    }

    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc]
                                          initWithTarget:self
                                          action:@selector(panBigLabel:)];
    [panGesture setCancelsTouchesInView:YES];
    [panGesture setDelaysTouchesBegan:YES];
    [self.bigLabel addGestureRecognizer:panGesture];
    
    UITapGestureRecognizer* statusTouch = [[UITapGestureRecognizer alloc]
                                          initWithTarget:self
                                          action:@selector(touchedStatus:)];
    [statusTouch setCancelsTouchesInView:YES];
    [statusTouch setDelaysTouchesBegan:YES];
    [_activityLabel addGestureRecognizer:statusTouch];
    
    [self addGestures:self.textView];
    [self addGestures:self.scrollView];
    [self addGestures:self.detailDescriptionLabel];
    [self addGestures:self.bigLabel];
    
    UISwipeGestureRecognizer* swipeGesture = [[UISwipeGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(handleSwipeUp:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.scrollView addGestureRecognizer:swipeGesture];
    
    if (_detailItem != Nil) {
        NSLog(@"started with a detail item defined");
    }
    UIBarButtonItem *doSomethingButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                      target:self
                                      action:@selector(doSomething:)];
    self.navigationItem.rightBarButtonItem = doSomethingButton;
    
    [self resizeWithoutMap];
}

- (void)addGestures:(UIView*)theView
{
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc]
                                          initWithTarget:self
                                          action:@selector(handleTap:)];
    [tapGesture setDelaysTouchesEnded:YES];
    [theView addGestureRecognizer:tapGesture];
    UISwipeGestureRecognizer* swipeGesture = [[UISwipeGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(handleSwipeLeft:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionLeft];
    [theView addGestureRecognizer:swipeGesture];
    swipeGesture = [[UISwipeGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(handleSwipeRight:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionRight];
    [theView addGestureRecognizer:swipeGesture];
}

#define DOSOMETHING (12345)
- (void)doSomething:(id)sender
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"What to do?"
                                                    message:@"Delete, ReGrab, or Favorite the tweet?"
                                                   delegate:self
                                          cancelButtonTitle: @"CANCEL"
                                          otherButtonTitles: @"DELETE TWEET", @"Refresh", @"Favorite", nil];
    [alert setTag:DOSOMETHING];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    @try {
        if ([alertView tag] == DOSOMETHING) {
            NSString* chosen = [alertView buttonTitleAtIndex:buttonIndex];
            if ([chosen compare:@"CANCEL"] == NSOrderedSame)
                return;
            if ([chosen compare:@"DELETE TWEET"] == NSOrderedSame) {
                [_master deleteTweet:_detailItem];
            } else if ([chosen compare:@"Refresh"] == NSOrderedSame) {
                [_master refreshTweet:_detailItem];
            } else if ([chosen compare:@"Favorite"] == NSOrderedSame) {
                [_master favoriteTweet:_detailItem];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    //NSLog(@"endScrollDrag velocity=(%f,%f)",velocity.x,velocity.y);
    if (velocity.x > 5) {
        [self.master nextTweet];
        //[self configureView];
    }
    if (velocity.x < -5) {
        [self.master prevTweet];
        //[self configureView];
    }
}

- (IBAction)touchedStatus:(id)sender
{
    [_activityLabel setHidden:YES];
}

- (IBAction)handleTap:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil)
                [_master nextTweet];
            else
                NSLog(@"NIL MASTER IN tap");
            //[self configureView];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}
- (IBAction)handleSwipeLeft:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil)
                [_master nextTweet];
            else
                NSLog(@"NIL MASTER IN tap");
            //[self configureView];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}
- (IBAction)handleSwipeRight:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil)
                [_master prevTweet];
            else
                NSLog(@"NIL MASTER IN tap");
            //[self configureView];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (IBAction)handleSwipeUp:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            [self.scrollView setHidden:YES];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (IBAction)panBigLabel:(UIGestureRecognizer *)gestureRecognizer
{
    static CGRect origFrame;
    @try {
        if (! [[gestureRecognizer class] isSubclassOfClass:[UIPanGestureRecognizer class]])
            return;
        UIPanGestureRecognizer* panGest = (UIPanGestureRecognizer*)gestureRecognizer;
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
            origFrame = [self.bigLabel frame];
        }
        CGPoint move = [panGest translationInView:[self view]];
        CGRect newFrame = [self.bigLabel frame];
        //newFrame.origin.x = origFrame.origin.x + move.x;
        newFrame.origin.y = origFrame.origin.y + move.y;
        [self.bigLabel setFrame:newFrame];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"MEMORY warning detail view");
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
