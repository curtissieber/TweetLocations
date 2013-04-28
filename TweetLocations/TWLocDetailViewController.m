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
#import "MovieGetter.h"
#import "DocumentViewController.h"
#import "TWLocPicCollectionCell.h"
#import <ImageIO/CGImageDestination.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>

@interface TWLocDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation TWLocDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    @try {
        if ( newDetailItem != Nil &&
            [[newDetailItem class] isSubclassOfClass:[Tweet class]] ) {
            _detailItem = newDetailItem;
            
            // Update the view.
            [self configureView];
            [_detailItem setHasBeenRead:[NSNumber numberWithBool:YES]];
            if ([[_detailItem fromGoogleReader] boolValue] == YES)
                [[_master googleReader] setRead:[_detailItem googleID] stream:[_detailItem googleStream]];
            [_master keepTrackofReadURLs:[_detailItem url]];
            NSManagedObjectContext *context = [_master.fetchedResultsController managedObjectContext];
            [context processPendingChanges];
        }
        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
    } @catch (NSException *eee) {
        [_activityView stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)configureView
{
    @try {
        [self checkForVideo:Nil];
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];
        [PhotoGetter setupImage:[_master redX] iview:_imageView sview:_scrollView button:_sizeButton];
        
        // Update the user interface for the detail item.
        if (self.detailItem) {
            [_activityLabel setHidden:YES];
            [self setupPicturesCollection];
            [_infoButton setHidden:([_detailItem origHTML] == Nil)];
            [_activityView startAnimating];
            
            Tweet *tweet = self.detailItem;
            int unread = 0;
            if (_master != Nil)
                unread = [_master unreadTweets];
            NSString* titleString = [NSString stringWithFormat:@"(%d unred) %@",unread,[tweet timestamp]];
            self.title = titleString;
            
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
            if ([[tweet hasBeenRead] boolValue] == YES) {
                [self.detailDescriptionLabel setTextColor:[UIColor redColor]];
                [self.bigLabel setTextColor:[UIColor redColor]];
            } else {
                [self.detailDescriptionLabel setTextColor:[UIColor whiteColor]];
                [self.bigLabel setTextColor:[UIColor whiteColor]];
            }
            [[_master updateQueue] addOperationWithBlock:^{
                [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
                [_master keepTrackofReadURLs:[_detailItem url]];
            }];
            
            NSMutableString* bigDetail = [[NSMutableString alloc] initWithFormat:@"[%@]: %@",
                                          [tweet username], [tweet tweet]];
            CATransition* textTrans = [CATransition animation];
            textTrans.duration = 0.4;
            textTrans.type = kCATransitionFade;
            textTrans.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            [self.bigLabel.layer addAnimation:textTrans forKey:@"changeTextTransition"];
            self.bigLabel.text = bigDetail;
            
            if (latitude > -900 && longitude > -900) {
                [self resizeForMap];
                [self displayMap:[tweet tweet] lat:latitude lon:longitude];
            } else {
                [self resizeWithoutMap];
                [self.mapView setHidden:YES];
            }
            
            [self.imageView setImage:Nil];
            [self.textView setText:Nil];
        }
        [[_master webQueue] addOperationWithBlock:^{
            [self imageConfig:[NSOperationQueue currentQueue]];
        }];
    } @catch (NSException *eee) {
        [_activityView stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)imageConfig:(NSOperationQueue*)mainQueue
{
    @try {
        __block Tweet* tweet = _detailItem;
        
        __block NSData* imageData = [_master imageData:[tweet url]];
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            @try {
                if (imageData != Nil) {
                    //NSLog(@"using cached data for %@",[tweet url]);
                    thisImageData = imageData;
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    
                    [self.scrollView setHidden:NO];
                    if ([PhotoGetter isGIFtype:[tweet url]])
                        [PhotoGetter setupGIF:image
                                        iview:self.imageView
                                        sview:self.scrollView
                                       button:self.sizeButton
                                      rawData:imageData];
                    else
                        [PhotoGetter setupImage:image
                                          iview:self.imageView
                                          sview:self.scrollView
                                         button:self.sizeButton];
                    
                    double latitude = [[tweet latitude] doubleValue];
                    double longitude = [[tweet longitude] doubleValue];
                    if (latitude > -900 && longitude > -900) {
                        [self resizeForMap];
                        [self displayMap:[tweet timestamp]
                                     lat:latitude
                                     lon:longitude];
                    }
                    
                    [_activityView stopAnimating];
                } else if ([[tweet url] length] > 4) {
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateNormal];
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateHighlighted];
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateSelected];
                    [self handleURL:[tweet url]];
                } else {
                    [UIView animateWithDuration:0.4 animations:^{
                        self.scrollView.hidden = YES;
                    }];
                    NSMutableString* nonono = [[NSMutableString alloc]initWithCapacity:500];
                    for (int i=0; i < 5; i++)
                        [nonono appendString:@"NO URL NO URL NO URL NO URL\n"];
                    [self.textView setText:nonono];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateNormal];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateHighlighted];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateSelected];
                    [_activityView stopAnimating];
                }
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }];
    } @catch (NSException *eee) {
        [_activityView stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (IBAction)infoButtonHit:(id)sender
{
    @try {
        if ([_detailItem origHTML] != Nil) {
            [UIView animateWithDuration:0.4 animations:^{
                _activityLabel.hidden = NO;
                NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithData:[_detailItem sourceDict]];
                NSString* detail = [NSString stringWithFormat:@"[%@]: %@\n****\n%@\n****\n%@", [_detailItem username], [_detailItem tweet], dict, [_detailItem origHTML]];
                [_activityLabel setText:detail];
            }];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)resizeForMap
{
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
    
    [UIView animateWithDuration:0.4 animations:^{
        [_bigLabel setFrame:bigFrame];
        [_scrollView setFrame:scrollFrame];
        [_textView setFrame:textFrame];
        [_mapView setFrame:mapFrame];
        [_detailDescriptionLabel setFrame:detailFrame];
    }];
}
- (void)resizeWithoutMap
{
    CGRect totalFrame = [[self view] frame];
    CGRect detailFrame = [_detailDescriptionLabel frame];
    CGRect mapFrame = [_mapView frame];
    CGRect textFrame = [_textView frame];
    CGRect scrollFrame = [_scrollView frame];
    __block CGRect bigFrame = [_bigLabel frame];
    
    // detail sits at the bottom
    detailFrame.origin.y = totalFrame.size.height - detailFrame.size.height;
    // map sits above the detail, but is hidden
    mapFrame.origin.y = detailFrame.origin.y - mapFrame.size.height;
    // big label starts at the very top
    bigFrame.origin.y = 0;
    //scroll sits above the detail and resizes for such
    scrollFrame.size.height = detailFrame.origin.y;
    scrollFrame.origin.y = 0;
    //text is the same as scrollframe
    textFrame.size.height = detailFrame.origin.y;
    textFrame.origin.y = 0;
    
    [UIView animateWithDuration:0.4 animations:^{
        [_bigLabel setFrame:bigFrame];
        [_scrollView setFrame:scrollFrame];
        [_textView setFrame:textFrame];
        [_mapView setFrame:mapFrame];
        [_detailDescriptionLabel setFrame:detailFrame];
    } completion:^(BOOL finished) {
        // big label ends at the very bottom
        bigFrame.origin.y = totalFrame.size.height - bigFrame.size.height;
        [UIView animateWithDuration:1.4 animations:^{
            [_bigLabel setFrame:bigFrame];
        }];
    }];
}

- (void)handleURL:(NSString*)url
{
    [self resizeWithoutMap];
    [self.mapView setHidden:YES];
    
    if ([TWLocDetailViewController imageExtension:url]) {
        [self openURL:[NSURL URLWithString:url]];
        return;
    }
    
    URLFetcher* fetcher = [[URLFetcher alloc] init];
    [fetcher fetch:url urlCallback:^(NSMutableString *html) {
        if (html != Nil) {
            [html appendString:@"\n"];
            [html appendString:[_detailItem tweet]];
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
    [self resizeWithoutMap];
    [self.mapView setHidden:YES];

    Tweet* originalTweet = _detailItem;
    NSString* urlStr = [url description];
    if (![TWLocDetailViewController imageExtension:urlStr]) {
        [self handleURL:urlStr]; // just grab the URL flat-up
    }
    
    [_activityView startAnimating];
    [[_master webQueue] addOperationWithBlock:^{
        NSData* picdata = [_master imageData:urlStr];
        if (picdata != Nil) {
            thisImageData = picdata;
            [self.scrollView setHidden:NO];
            [[_master updateQueue] addOperationWithBlock:^{
                UIImage *image = [[UIImage alloc] initWithData:picdata];
                if ([PhotoGetter isGIFtype:urlStr])
                    [PhotoGetter setupGIF:image iview:self.imageView sview:self.scrollView button:self.sizeButton rawData:picdata];
                else
                    [PhotoGetter setupImage:image iview:self.imageView sview:self.scrollView button:self.sizeButton];
                if (originalTweet != _detailItem) { // oops we moved !!
                    [_activityView stopAnimating];
                    return;
                }
                CGImageSourceRef  source = CGImageSourceCreateWithData((__bridge CFDataRef)picdata, NULL);
                NSDictionary* metadataNew = (__bridge NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,0,NULL);
                //NSLog(@"%@",metadataNew);
                NSDictionary* gpsInfo = [metadataNew objectForKey:@"{GPS}"];
                id latitude = [gpsInfo objectForKey:@"Latitude"];
                id latitudeRef = [gpsInfo objectForKey:@"LatitudeRef"];
                id longitude = [gpsInfo objectForKey:@"Longitude"];
                id longitudeRef = [gpsInfo objectForKey:@"LongitudeRef"];
                NSDictionary* exifInfo = [metadataNew objectForKey:@"{Exif}"];
                id timestamp = [exifInfo objectForKey:@"DateTimeOriginal"];
                //NSLog(@"Lat=%@%@ Lon=%@%@ time=%@",latitude,latitudeRef,longitude,longitudeRef,timestamp);
                float lat = -1000;
                float lon = -1000;
                if (latitude != Nil && latitudeRef != Nil &&
                    longitude != Nil && longitudeRef != Nil) {
                    lat = [(NSNumber*)latitude floatValue];
                    if ([(NSString*)latitudeRef compare:@"S"] == NSOrderedSame)
                        lat = 0-lat;
                    lon = [(NSNumber*)longitude floatValue];
                    if ([(NSString*)longitudeRef compare:@"W"] == NSOrderedSame)
                        lon = 0-lon;
                }
                if (lat > -900) {
                    [self resizeForMap];
                    [self displayMap:timestamp lat:lat lon:lon];
                    [[_master updateQueue] addOperationWithBlock:^{
                        [_detailItem setLocationFromPic:[NSNumber numberWithBool:YES]];
                        [_detailItem setLatitude:[NSNumber numberWithDouble:lat]];
                        [_detailItem setLongitude:[NSNumber numberWithDouble:lon]];
                        [_detailItem setUrl:urlStr];
                    }];
                } else {
                    [[_master updateQueue] addOperationWithBlock:^{
                        [_detailItem setUrl:urlStr];
                    }];
                }
                
                [_activityView stopAnimating];
            }];
            return;
        }
        [[_master updateQueue] addOperationWithBlock:^{
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
                            [[_master webQueue] addOperationWithBlock:^{
                                [_master imageData:data forURL:urlStr];
                                [[_master.fetchedResultsController managedObjectContext] processPendingChanges];
                            }];
                        }
                        if (originalTweet != _detailItem) { // oops we moved !!
                            [_activityView stopAnimating];
                            return;
                        }
                        if (latitude > -900) {
                            [self resizeForMap];
                            [self displayMap:timestamp lat:latitude lon:longitude];
                            [[_master updateQueue] addOperationWithBlock:^{
                                [_detailItem setLocationFromPic:[NSNumber numberWithBool:YES]];
                                [_detailItem setLatitude:[NSNumber numberWithDouble:latitude]];
                                [_detailItem setLongitude:[NSNumber numberWithDouble:longitude]];
                                [_detailItem setUrl:urlStr];
                            }];
                        } else {
                            [[_master updateQueue] addOperationWithBlock:^{
                                [_detailItem setUrl:urlStr];
                            }];
                        }
                        
                        [_activityView stopAnimating];
                    }];
        }];
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
    if ([urlStr compare:@".jpg:large" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".png" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".gif" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr rangeOfString:@"tumblr.com/video_file/"].location != NSNotFound)
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
            if ([urlStr compare:@"tel:" options:0 range:NSMakeRange(0, 4)] != NSOrderedSame) {
                if ([urlStr rangeOfString:@"%5C"].location != NSNotFound) {
                    NSRange range = [urlStr rangeOfString:@"%5C"];
                    urlStr = [urlStr substringToIndex:range.location];
                }
                if ([urlStr rangeOfString:@"http"].location != 0) {
                    NSRange range = [urlStr rangeOfString:@"http"];
                    if (range.location != NSNotFound)
                        urlStr = [urlStr substringFromIndex:range.location];
                }
                [strResults addObject:urlStr];
                *stop = ([strResults count] > 100);
            }
        }
    }];
    return strResults;
}

- (void)findJPG:(NSMutableString*)html theUrlStr:(NSString*)url
{
    NSString* replace = [TWLocDetailViewController staticFindJPG:html theUrlStr:url];
    [self.textView setText:html];
    [self checkForVideo:[NSSet setWithArray:[html componentsSeparatedByString:@"\n"]]];
    if ([_detailItem origHTML] == Nil ||
        [url rangeOfString:@".tumblr.com/image/"].location != NSNotFound) {
        [[_master updateQueue] addOperationWithBlock:^{
            [_detailItem setOrigHTML:html];
        }];
        [_infoButton setHidden:NO];
        [self setupPicturesCollection];
    }
    if (replace != Nil) {
        if ([TWLocDetailViewController imageExtension:replace])
            [self openURL:[NSURL URLWithString:replace]];
        else 
            [self handleURL:replace];
    } else {
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
        else if ([current rangeOfString:@".tumblr.com/previews/"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"media.tumblr.com/"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinterest.com/500"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinterest.com/550"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinterest.com/original"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinimg.com/500"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinimg.com/550"].location != NSNotFound)
            [strResults addObject:current];
        else if ([current rangeOfString:@"pinimg.com/original"].location != NSNotFound)
            [strResults addObject:current];
    }
    //NSLog(@"only %d links are images",[strResults count]);
    
    [strResults sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSMutableString* str1 = [[NSMutableString alloc] initWithString:obj1];
        NSMutableString* str2 = [[NSMutableString alloc] initWithString:obj2];
        if ([str1 rangeOfString:@"tumblr.com/video_file/"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str1 rangeOfString:@"tumblr.com/video_file/"].location != NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinterest.com/original"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str1 rangeOfString:@"pinterest.com/original"].location != NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinimg.com/original"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str1 rangeOfString:@"pinimg.com/original"].location != NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinterest.com/550"].location != NSNotFound &&
            [str2 rangeOfString:@"pinterest.com/original"].location == NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@"pinterest.com/550"].location != NSNotFound &&
            [str1 rangeOfString:@"pinterest.com/original"].location == NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinimg.com/550"].location != NSNotFound &&
            [str2 rangeOfString:@"pinimg.com/original"].location == NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@"pinimg.com/550"].location != NSNotFound &&
            [str1 rangeOfString:@"pinimg.com/original"].location == NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinterest.com/500"].location != NSNotFound &&
            [str2 rangeOfString:@"pinterest.com/550"].location == NSNotFound &&
            [str2 rangeOfString:@"pinterest.com/original"].location == NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@"pinterest.com/500"].location != NSNotFound &&
            [str1 rangeOfString:@"pinterest.com/550"].location == NSNotFound &&
            [str1 rangeOfString:@"pinterest.com/original"].location == NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@"pinimg.com/500"].location != NSNotFound &&
            [str2 rangeOfString:@"pinimg.com/550"].location == NSNotFound &&
            [str2 rangeOfString:@"pinimg.com/original"].location == NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@"pinimg.com/500"].location != NSNotFound &&
            [str1 rangeOfString:@"pinimg.com/550"].location == NSNotFound &&
            [str1 rangeOfString:@"pinimg.com/original"].location == NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@".tumblr.com/image/"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@".tumblr.com/image/"].location != NSNotFound)
            return NSOrderedDescending;
        if ([str1 rangeOfString:@".tumblr.com/previews/"].location != NSNotFound)
            return NSOrderedAscending;
        if ([str2 rangeOfString:@".tumblr.com/previews/"].location != NSNotFound)
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
    
    if ([strResults count] > 0) {
        e = [strResults objectEnumerator];
        while ((str = [e nextObject]) != Nil) {
            [allMatches appendString:str];
            [allMatches appendString:@"\n"];
            [allMatches appendString:@"\n"];
        }
    } else {
        [allMatches appendString:@"FULL URL LISTING\n\n"];
        e = [htmlResults objectEnumerator];
        while ((str = [e nextObject]) != Nil) {
            [allMatches appendString:str];
            [allMatches appendString:@"\n"];
            [allMatches appendString:@"\n"];
        }
    }

    [html setString:allMatches];
    if (replaceStr != Nil) {
        return replaceStr;
    }
    return Nil;
}

static MKCoordinateRegion region;
- (void)displayMap:(NSString*)text lat:(double)latitude lon:(double)longitude
{
    @try {
        [self.mapView setHidden:NO];

        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latitude, longitude);
        region = MKCoordinateRegionMake(coord,
                                                           MKCoordinateSpanMake(10.0, 10.0));
        
        NSArray* annotations = [self.mapView annotations];
        [self.mapView removeAnnotations:annotations];
        
        MKPointAnnotation* point = [[MKPointAnnotation alloc] init];
        point.coordinate = coord;
        point.title = text;
        [self.mapView addAnnotation:point];
        
        [self.mapView setCenterCoordinate:coord animated:YES];
        [self.mapView setRegion:region animated:YES];
        
        [self performSelector:@selector(setMapRegion:) withObject:Nil afterDelay:3.0];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)setMapRegion:(id)dummy
{
    @try {
        region.span.latitudeDelta /= 3.0;
        region.span.longitudeDelta /= 3.0;
        [self.mapView setRegion:region animated:YES];
        NSLog(@"REGION set to %0.3f %0.3f", region.span.latitudeDelta,region.span.longitudeDelta);
        double delay = 2.0;
        if (region.span.latitudeDelta < 0.1)
            delay = 1.0;
        if (region.span.latitudeDelta > 0.003)
            [self performSelector:@selector(setMapRegion:) withObject:Nil afterDelay:delay];
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
        [[self sizeButton] setEnabled:NO];
        [[self sizeButton] setHidden:YES];
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
static UIBarButtonItem *doSomethingButton;
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [_mapView setHidden:YES];
    [_scrollView setHidden:YES];
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
    swipeGesture = [[UISwipeGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(handleSwipeDown:)];
    [swipeGesture setDirection:UISwipeGestureRecognizerDirectionDown];
    [self.scrollView addGestureRecognizer:swipeGesture];
    
    if (_detailItem != Nil) {
        NSLog(@"started with a detail item defined");
    }
    doSomethingButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                      target:self
                                      action:@selector(doSomething:)];
    self.navigationItem.rightBarButtonItem = doSomethingButton;
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

#define ALERT_DOSOMETHING (12345)
#define ALERT_SAVEVIDEO (777)
#define ALERT_TAG_NULL (1)
#define DOSOMETHING_CANCEL @"CANCEL"
#define DOSOMETHING_DELETE @"DELETE Tweet"
#define DOSOMETHING_REFRESH @"Refesh Tweet Links"
#define DOSOMETHING_FAVORITE @"Favorite Tweet"
#define DOSOMETHING_DOCUMENTS @"View Saved Movies"
- (void)doSomething:(id)sender
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UIActionSheet* action = [[UIActionSheet alloc] initWithTitle:@"What to do?" delegate:self cancelButtonTitle:DOSOMETHING_CANCEL destructiveButtonTitle:DOSOMETHING_DELETE otherButtonTitles:DOSOMETHING_REFRESH, DOSOMETHING_FAVORITE, DOSOMETHING_DOCUMENTS, nil];
        [action setTag:ALERT_DOSOMETHING];
        [action showFromBarButtonItem:doSomethingButton animated:YES];
        return;
    } 
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"What to do?"
                                                    message:@"Delete, ReGrab, or Favorite?"
                                                   delegate:self
                                          cancelButtonTitle: DOSOMETHING_CANCEL
                                          otherButtonTitles: DOSOMETHING_REFRESH, DOSOMETHING_FAVORITE, DOSOMETHING_DOCUMENTS, DOSOMETHING_DELETE, nil];
    [alert setTag:ALERT_DOSOMETHING];
    [alert show];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    @try {
        if ([actionSheet tag] == ALERT_DOSOMETHING) {
            NSString* chosen = [actionSheet buttonTitleAtIndex:buttonIndex];
            if ([chosen compare:DOSOMETHING_CANCEL] == NSOrderedSame)
                return;
            if ([chosen compare:DOSOMETHING_DELETE] == NSOrderedSame) {
                [_master deleteTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_REFRESH] == NSOrderedSame) {
                [_master refreshTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_FAVORITE] == NSOrderedSame) {
                [_master favoriteTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_DOCUMENTS] == NSOrderedSame) {
                [self doDocumentsView];
            }
        } 
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    @try {
        if ([alertView tag] == ALERT_DOSOMETHING) {
            NSString* chosen = [alertView buttonTitleAtIndex:buttonIndex];
            if ([chosen compare:DOSOMETHING_CANCEL] == NSOrderedSame)
                return;
            if ([chosen compare:DOSOMETHING_DELETE] == NSOrderedSame) {
                [_master deleteTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_REFRESH] == NSOrderedSame) {
                [_master refreshTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_FAVORITE] == NSOrderedSame) {
                [_master favoriteTweet:_detailItem];
            } else if ([chosen compare:DOSOMETHING_DOCUMENTS] == NSOrderedSame) {
                [self doDocumentsView];
            }
        } else if ([alertView tag] == ALERT_SAVEVIDEO) {
            NSString* chosen = [alertView buttonTitleAtIndex:buttonIndex];
            if ([chosen compare:@"NO"] == NSOrderedSame)
                return;
            NSString* name = [[alertView textFieldAtIndex:0] text];
            NSLog(@"saving movie with name %@",name);
            [self saveVideo:name];
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
    }
    if (velocity.x < -5) {
        [self.master prevTweet];
    }
}

- (IBAction)touchedStatus:(id)sender
{
    [UIView animateWithDuration:0.4 animations:^{
        _activityLabel.hidden = YES;
    }];
}

- (IBAction)handleTap:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [[_master webQueue] addOperationWithBlock:^{
                        [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            [_master keepTrackofReadURLs:obj];
                            //[_master deleteImageData:obj];
                            //  NSLog(@"deleting from pic collection %@",obj);
                        }];
                    }];
                [_master nextNewTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}
- (IBAction)handleSwipeLeft:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [[_master webQueue] addOperationWithBlock:^{
                        [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            [_master keepTrackofReadURLs:obj];
                            //[_master deleteImageData:obj];
                            // NSLog(@"deleting from pic collection %@",obj);
                        }];
                    }];
                [_master nextTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}
- (IBAction)handleSwipeRight:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_master != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [[_master webQueue] addOperationWithBlock:^{
                        [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            [_master keepTrackofReadURLs:obj];
                            //[_master deleteImageData:obj];
                            // NSLog(@"deleting from pic collection %@",obj);
                        }];
                    }];
                [_master prevTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (IBAction)handleSwipeUp:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (_picCollection && [_picCollection isHidden] == NO) {
                [_picCollection setHidden:YES];
                return;
            }
            self.textView.alpha = 0.0;
            [UIView animateWithDuration:0.6 delay:0.01 options:UIViewAnimationOptionCurveLinear animations:^{
                self.scrollView.alpha = 0.0;
                self.textView.alpha = 1.0;
            } completion:^(BOOL finished) {
                self.scrollView.hidden = YES;
                self.scrollView.alpha = 1.0;
            }];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (IBAction)handleSwipeDown:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if (self.picCollection)
                [self.picCollection setHidden:![self.picCollection isHidden]];
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

- (void)setupPicturesCollection
{
    @try {
        [_picCollection setHidden:YES];
        [_picButton setHidden:YES];
        _pictures = Nil;
        
        bool isTumblr = [[_detailItem url] rangeOfString:@"tumblr.com"].location != NSNotFound ||
                [[_detailItem url] rangeOfString:@"tmblr.co"].location != NSNotFound;
        bool isGWIP = [[_detailItem url] rangeOfString:@"guyswithiphones.com"].location != NSNotFound;
        bool isInstagram = [[_detailItem url] rangeOfString:@"/instagr.am/"].location != NSNotFound;
        bool isOwly = [[_detailItem url] rangeOfString:@"/ow.ly/"].location != NSNotFound;
        bool isMoby = [[_detailItem url] rangeOfString:@"/moby.to/"].location != NSNotFound;
        bool isYouTube = [[_detailItem url] rangeOfString:@"youtube.com/"].location != NSNotFound ||
                [[_detailItem url] rangeOfString:@"/youtu.be/"].location != NSNotFound;
        NSArray* urls = [[_detailItem origHTML] componentsSeparatedByString:@"\n"];
        NSSet* urlset = [NSSet setWithArray:urls];
        urlset = [urlset objectsPassingTest:^BOOL(id obj, BOOL *stop) {
            NSString* theURL = obj;
            if ([TWLocDetailViewController imageExtension:theURL]) {
                if ([theURL rangeOfString:@"twimg.com/profile_images"].location != NSNotFound)
                    return NO;
                else if ([theURL rangeOfString:@"/hprofile"].location != NSNotFound)
                    return NO;
                else if (isTumblr) {
                    if ([theURL rangeOfString:@"media.tumblr.com"].location != NSNotFound &&
                        [theURL rangeOfString:@"/tumblr_"].location != NSNotFound)
                        return YES;
                    return NO;
                } else if (isGWIP) {
                    if ([theURL rangeOfString:@"guyswithiphones.com/201"].location != NSNotFound)
                        return YES;
                    return NO;
                } else if (isInstagram) {
                    if ([theURL rangeOfString:@"distilleryimage"].location != NSNotFound &&
                        [theURL rangeOfString:@".instagram.com/"].location != NSNotFound)
                        return YES;
                    return NO;
                } else if (isOwly) {
                    if ([theURL rangeOfString:@"//static.ow.ly/"].location != NSNotFound &&
                        [theURL rangeOfString:@"/normal/"].location != NSNotFound)
                        return YES;
                    return NO;
                } else if (isMoby) {
                    if ([theURL rangeOfString:@"mobypicture.com/"].location != NSNotFound &&
                        [theURL rangeOfString:@"_view."].location != NSNotFound)
                        return YES;
                    return NO;
                } else if (isYouTube) {
                    if ([theURL rangeOfString:@"/hqdefault."].location != NSNotFound)
                        return YES;
                    return NO;
                }
                return YES;
            }
            return NO;
        }];
        if (isTumblr)
            urlset = [self removeTumblrDups:urlset];
        NSLog(@"THE SET OF PICS:\n%@",[urlset description]);
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if ([urlset count] > 1) {
                [_picCollection setHidden:NO];
                [_picButton setHidden:NO];
                _pictures = [urlset allObjects];
                [_picCollection reloadData];
                [_picCollection setNeedsDisplay];
                [_picCollection setNeedsLayout];
                [_picCollection setNeedsUpdateConstraints];
                [_picCollection selectItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                [_picCollection scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
                [_picButton setHidden:NO];
                [_picButton setTitle:[NSString stringWithFormat:@"%d Pics",[_pictures count]] forState:UIControlStateNormal];
                __block CGRect origFrame = [_picButton frame];
                [UIView animateWithDuration:0.9 animations:^{
                    CGRect newFrame;
                    newFrame.origin.x = origFrame.origin.x - origFrame.size.width*2;
                    newFrame.origin.y = origFrame.origin.y;
                    newFrame.size.width = origFrame.size.width * 3;
                    newFrame.size.height = origFrame.size.height * 3;
                    [_picButton setFrame:newFrame];
                } completion:^(BOOL finished) {
                    if (!finished)
                        NSLog(@"reducing the collectionButton, tho not finished");
                    [_picButton setFrame:origFrame];
                    [UIView animateWithDuration:1.0 animations:^{
                        [_picCollection setHidden:YES];
                    }];
                }];
                [self checkForVideo:[NSSet setWithArray:urls]];
            } 
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}
- (NSSet*)removeTumblrDups:(NSSet*)urlset
{
    NSMutableSet* retset = [[NSMutableSet alloc] initWithCapacity:1];
    @try {
        [urlset enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            NSString* theURL = obj;
            NSRange filenamerange = [theURL rangeOfString:@"/tumblr_"];
            if (filenamerange.location == NSNotFound) {
                [retset addObject:theURL];
            } else {
                NSString* filename = [theURL substringFromIndex:filenamerange.location];
                NSArray* filecomps = [filename componentsSeparatedByString:@"_"];
                if ([filecomps count] < 3)
                    [retset addObject:theURL];
                else {
                    NSString* hash = [filecomps objectAtIndex:1];
                    NSString* ext = [filecomps objectAtIndex:2];
                    __block bool match = ([ext length] < 5);
                    [retset enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString* matchURL = obj;
                        if ([matchURL rangeOfString:hash].location != NSNotFound)
                            match = *stop = YES;
                    }];
                    if (!match)
                        [retset addObject:theURL];
                }
            }
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
    return retset;
}
- (IBAction)picturesButtonHit:(id)sender
{
    [_picCollection setHidden:(![_picCollection isHidden])];
}

static NSString* videoURL = Nil;

- (void)checkForVideo:(NSSet*)urls
{
    @try {
        if (urls == Nil) {
            [_videoButton setHidden:YES];
            return;
        }
        __block bool hasVideo = NO;
        [urls enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            NSString* theURL = obj;
            if ([theURL rangeOfString:@"tumblr.com/video_file/"].location != NSNotFound) {
                hasVideo = *stop = YES;
                videoURL = theURL;
            }
        }];
        [_videoButton setHidden:(!hasVideo)];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (IBAction)videoButtonHit:(id)sender
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"SAVE VIDEO" message:[NSString stringWithFormat:@"Save the %@ video?",videoURL] delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES, save", nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    alert.tag = ALERT_SAVEVIDEO;
    [alert show];
}
- (void)saveVideo:(NSString*)additionalName
{
    NSLog(@"Needing to save %@ to file", videoURL);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString* lastNamePart;
    lastNamePart = [NSString stringWithFormat:@"%@ %@%@", additionalName,
                    videoURL.lastPathComponent, @".mp4"];
    NSString* filename = [documentsDirectory
                          stringByAppendingPathComponent:
                          lastNamePart];
    NSLog(@"the filename will be %@",filename);
    
    [_activityView startAnimating];
    MovieGetter* getter = [[MovieGetter alloc] init];
    [getter fetch:[NSURL URLWithString:videoURL]
         intoFile:filename
      urlCallback:^(long long dataSize, BOOL complete, BOOL success) {
          if (complete) {
              float datasize = dataSize / 1024.0 / 1024.0;
              NSString* status = [NSString stringWithFormat:
                                  @"download complete into %@, %.2f MB of data, %@",
                                  filename, datasize, success ? @"SUCCESS" : @"FAIL"];
              NSLog(@"%@",status);
              if (success) {
                  UIAlertView *alert =
                  [[UIAlertView alloc] initWithTitle:@"Movie saved"
                                             message:status
                                            delegate:self
                                   cancelButtonTitle:@"YAY"
                                   otherButtonTitles: nil];
                  [alert setCancelButtonIndex:0];
                  [alert setTag:ALERT_TAG_NULL];
                  [alert show];
              } else {
                  UIAlertView *alert =
                  [[UIAlertView alloc] initWithTitle:@"Movie cannot be saved"
                                             message:status
                                            delegate:self
                                   cancelButtonTitle:@"BOO"
                                   otherButtonTitles: nil];
                  [alert setCancelButtonIndex:0];
                  [alert setTag:ALERT_TAG_NULL];
                  [alert show];
              }
              
              [[_master queueLabel] setText:filename];
              [_activityView stopAnimating];
          } else { // not complete
              float datasize = dataSize / 1024.0 / 1024.0;
              [[_master queueLabel] setText:[NSString stringWithFormat:@"%.2f MB",datasize]];
          }
      }];
}
- (void)doDocumentsView
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSFileManager* fManager = [NSFileManager defaultManager];
    NSArray* files = [fManager contentsOfDirectoryAtPath:documentsDirectory error:Nil];
    NSMutableArray* filesizes = [[NSMutableArray alloc] initWithCapacity:[files count]];
    
    NSEnumerator *e = [files objectEnumerator];
    NSString* file;
    long long totalsize = 0;
    while ((file = [e nextObject]) != Nil) {
        NSDictionary* filevalues = [fManager attributesOfItemAtPath:[documentsDirectory stringByAppendingPathComponent:file] error:Nil];
        NSNumber* fsize = [NSNumber numberWithLongLong:[filevalues fileSize]];
        [filesizes addObject:fsize];
        totalsize += [filevalues fileSize];
    }
    
    UIStoryboard *stsettings = [UIStoryboard storyboardWithName:@"DocumentViewController"
                                                         bundle:Nil];
    DocumentViewController *dview = [stsettings instantiateInitialViewController];
    [dview setTheData:files];
    [dview setFilesizes:filesizes];
    [dview setTitle:@"Documents"];
    [dview setDetailView:self];
    [dview setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [dview setModalPresentationStyle:UIModalPresentationFullScreen];
    [self presentViewController:dview animated:YES completion:Nil];
}

#pragma mark Collection View Data Source
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        TWLocPicCollectionCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"picture" forIndexPath:indexPath];
        int idx = [indexPath row];
        //[[cell image] setImage:[_pictures objectAtIndex:idx]];
        [[cell image] setImage:[_master redX]];
        NSString* urlstr = [_pictures objectAtIndex:idx];
        if (urlstr == Nil)
            return cell;
        [[_master webQueue] addOperationWithBlock:^{
            [self collectionCellPicture:urlstr imageView:[cell image]];
        }];
        return cell;
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
    return Nil;
}

- (void)collectionCellPicture:(NSString*)urlstr imageView:(UIImageView*)iview
{
    @try {
        NSData* picdata = [_master imageData:urlstr];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            PhotoGetter* getter = [[PhotoGetter alloc] init];
            if (picdata == Nil) {
                [getter getPhoto:[NSURL URLWithString:urlstr]
                            into:iview
                          scroll:Nil
                       sizelabel:Nil
                        callback:^(float latitude, float longitude, NSString *timestamp, NSData *imageData) {
                            [[_master webQueue] addOperationWithBlock:^{
                                [_master imageData:imageData forURL:urlstr];
                            }];
                        }];
            } else {
                UIImage *image = [[UIImage alloc] initWithData:picdata];
                
                [self.scrollView setHidden:NO];
                if ([PhotoGetter isGIFtype:urlstr])
                    [PhotoGetter setupGIF:image
                                    iview:iview
                                    sview:Nil
                                   button:Nil
                                  rawData:picdata];
                else
                    [PhotoGetter setupImage:image
                                      iview:iview
                                      sview:Nil
                                     button:Nil];
            }

        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (_pictures == Nil)
        return 0;
    return [_pictures count];
}

#pragma mark Collection View Delegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        int idx = [indexPath row];
        NSLog(@"selected picture %d",idx);
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];

        [self openURL:[NSURL URLWithString:[_pictures objectAtIndex:idx]]];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[ee callStackSymbols] );
    }
}

@end
