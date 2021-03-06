//
//  TWLocDetailViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocBigDetailViewController.h"
#import "TWLocMasterViewController.h"
#import "PhotoGetter.h"
#import "URLFetcher.h"
#import "MovieGetter.h"
#import "DocumentViewController.h"
#import "WebViewController.h"
#import "TWLocPicCollectionCell.h"
#import <ImageIO/CGImageDestination.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <MediaPlayer/MediaPlayer.h>

@interface TWLocBigDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation TWLocBigDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    @try {
        videoURL = Nil;
        if ( newDetailItem != Nil &&
            [[newDetailItem class] isSubclassOfClass:[Tweet class]] ) {
            [super setDetailItem:newDetailItem];
            
            // Update the view.
            [self configureView];
            [[self detailItem] setHasBeenRead:[NSNumber numberWithBool:YES]];
            [[self master] keepTrackofReadURLs:[[self detailItem] url]];
            NSManagedObjectContext *context = [[self master].fetchedResultsController managedObjectContext];
            [context processPendingChanges];
        }
        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
    } @catch (NSException *eee) {
        [[self activityView] stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)configureView
{
    @try {
        [self checkForVideo:Nil];
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];
        [PhotoGetter setupImage:[[self master] redX] iview:_imageView sview:_scrollView button:_sizeButton animate:YES];
        
        // Update the user interface for the detail item.
        if (self.detailItem) {
            //[[self activityLabel] setHidden:YES];
            [self setupPicturesCollection];
            [_infoButton setHidden:([[self detailItem] origHTML] == Nil)];
            [[self activityView] startAnimating];
            
            Tweet *tweet = self.detailItem;
            [self updateTitle];
            
            NSMutableString* detail = [[NSMutableString alloc] initWithFormat:@"%@\n[%@] %@\n",
                                       [tweet tweet] ,[tweet username], [tweet acountListPrefix]];
            if ([[tweet url] length] > 4)
                [detail appendFormat:@" [%@]", [[tweet url] componentsSeparatedByString:@"\n"]];
            double latitude = [[tweet latitude] doubleValue];
            double longitude = [[tweet longitude] doubleValue];
            if (latitude > -900 && longitude > -900)
                [detail appendFormat:@" [%0.1lf,%0.1lf]",latitude,longitude];
            [detail appendFormat:@" %@",[tweet timestamp]];
            
            [self.detailDescriptionLabel setText:detail];
            if ([[tweet hasBeenRead] boolValue] == YES) {
                [self.detailDescriptionLabel setTextColor:[UIColor redColor]];
                [self.bigLabel setTextColor:[UIColor redColor]];
                [self.usernameLabel setTextColor:[UIColor redColor]];
            } else {
                [self.detailDescriptionLabel setTextColor:[UIColor whiteColor]];
                [self.bigLabel setTextColor:[UIColor whiteColor]];
                [self.usernameLabel setTextColor:[UIColor blackColor]];
            }
            [[[self master] updateQueue] addOperationWithBlock:^{
                [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
                [[self master] keepTrackofReadURLs:[[self detailItem] url]];
            }];
            
            NSMutableString* bigDetail = [[NSMutableString alloc] initWithFormat:@"%@\n[%@] %@",
                                          [tweet tweet], [tweet username], [tweet acountListPrefix]];
            CATransition* textTrans = [CATransition animation];
            textTrans.duration = 0.2;
            textTrans.type = kCATransitionFade;
            textTrans.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            [self.bigLabel.layer addAnimation:textTrans forKey:@"changeTextTransition"];
            self.bigLabel.text = bigDetail;
            [_usernameLabel setText:[tweet username]];
            [_usernameLabel sizeToFit];
            
            if (latitude > -900 && longitude > -900 && [[[self detailItem] locationFromPic]boolValue]) {
                [self resizeForMap];
                [self displayMap:[tweet tweet] lat:latitude lon:longitude];
            } else {
                [self resizeWithoutMap];
                [self.mapView setHidden:YES];
            }
            
            [self.imageView setImage:Nil];
            [self.textView setText:Nil];
        }
        [[[self master] multipleOpQueue] addOperationWithBlock:^{
            [self imageConfig:[NSOperationQueue currentQueue]];
        }];
    } @catch (NSException *eee) {
        [[self activityView] stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)imageConfig:(NSOperationQueue*)mainQueue
{
    @try {
        __block Tweet* tweet = [self detailItem];
        
        NSString* thisURL = [[[tweet url] componentsSeparatedByString:@"\n"] firstObject];
        lastURLopened = thisURL;
        __block NSData* imageData = [[self master] imageData:thisURL];
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            @try {
                if (imageData != Nil) {
                    if ([[tweet tweet] rangeOfString:@"@"].location != NSNotFound)
                        [_usernameLabel setText:[NSString stringWithFormat:@"%@🐣🐣🐣",[_usernameLabel text]]];
                    thisImageData = imageData;
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    
                    [self.scrollView setHidden:NO];
                    if ([PhotoGetter isGIFtype:thisURL])
                        [PhotoGetter setupGIF:image
                                        iview:self.imageView
                                        sview:self.scrollView
                                       button:self.sizeButton
                                      rawData:imageData animate:YES];
                    else
                        [PhotoGetter setupImage:image
                                          iview:self.imageView
                                          sview:self.scrollView
                                         button:self.sizeButton animate:YES];
                    [[self master] keepTrackofReadURLs:thisURL];

                    [self.view setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];
                    [self.scrollView setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];
                    double latitude = [[tweet latitude] doubleValue];
                    double longitude = [[tweet longitude] doubleValue];
                    if (latitude > -900 && longitude > -900 && [[tweet locationFromPic] boolValue]) {
                        [self resizeForMap];
                        [self displayMap:[tweet timestamp]
                                     lat:latitude
                                     lon:longitude];
                    }
                    
                    [[self activityView] stopAnimating];
                    /*if ([tweet origHTML] == Nil)
                        [self handleURL:[tweet origURL]];
                    else*/
                        [self checkForVideo:[URLProcessor getURLs:[tweet origHTML]]];
                } else if ([thisURL length] > 4) {
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateNormal];
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateHighlighted];
                    [[self sizeButton] setTitle:@"no pic" forState:UIControlStateSelected];
                    [self handleURL:thisURL];
                } else {
                    [UIView animateWithDuration:0.2 animations:^{
                        self.scrollView.hidden = YES;
                    }];
                    NSMutableString* nonono = [[NSMutableString alloc]initWithCapacity:500];
                    for (int i=0; i < 5; i++)
                        [nonono appendString:@"NO URL NO URL NO URL NO URL\n"];
                    [self.textView setText:nonono];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateNormal];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateHighlighted];
                    [[self sizeButton] setTitle:@"no url" forState:UIControlStateSelected];
                    [[self activityView] stopAnimating];
                }
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
        }];
    } @catch (NSException *eee) {
        [[self activityView] stopAnimating];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (IBAction)infoButtonHit:(id)sender
{
    @try {
        if ([[self detailItem] origHTML] != Nil) {
            [UIView animateWithDuration:0.2 animations:^{
                [self activityLabel].hidden = NO;
                NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithData:[[self detailItem] sourceDict]];
                NSString* detail = [NSString stringWithFormat:@"[%@] %@: %@\n****\n%@\n****\n%@", [[self detailItem] username], [[self detailItem] acountListPrefix], [[self detailItem] tweet], dict, [[self detailItem] origHTML]];
                [[self activityLabel] setText:detail];
            }];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)resizeForMap
{
    [self resizeWithoutMap];
    
    CGRect totalFrame = [[self view] frame];
    CGRect detailFrame = [_detailDescriptionLabel frame];
    CGRect mapFrame = [_mapView frame];
    CGRect textFrame = [_textView frame];
    CGRect scrollFrame = [_scrollView frame];
    __block CGRect bigFrame = [_bigLabel frame];
    
    // detail sits at the bottom
    detailFrame.origin.y = totalFrame.size.height - detailFrame.size.height - totalFrame.origin.y;
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
    CGRect usernameFrame = [_usernameLabel frame];
    usernameFrame.origin.x = 0;
    usernameFrame.origin.y = mapFrame.origin.y - usernameFrame.size.height;
    [_usernameLabel setCenter:[_scrollView center]];
    
    [UIView animateWithDuration:0.4 animations:^{
        [_bigLabel setFrame:bigFrame];
        [_scrollView setFrame:scrollFrame];
        [_textView setFrame:textFrame];
        [_mapView setFrame:mapFrame];
        [_detailDescriptionLabel setFrame:detailFrame];
    } completion:^(BOOL finished) {
        // big label ends at the very bottom
        if (finished) {
            bigFrame.origin.y = totalFrame.size.height - bigFrame.size.height;
            [UIView animateWithDuration:0.5 animations:^{
                [_bigLabel setFrame:bigFrame];
                [_usernameLabel setFrame:usernameFrame];
            }];
        }
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
    // big label starts at the middle
    bigFrame.origin.y = (totalFrame.size.height - bigFrame.size.height)*4.0/5.0;
    //scroll sits above the detail and resizes for such
    scrollFrame.size.height = detailFrame.origin.y;
    scrollFrame.origin.y = 0;
    //text is the same as scrollframe
    textFrame.size.height = detailFrame.origin.y;
    textFrame.origin.y = 0;
    __block CGRect usernameFrame = [_usernameLabel frame];
    usernameFrame.origin.x = 0;
    usernameFrame.origin.y = detailFrame.origin.y - usernameFrame.size.height;
    [_usernameLabel setCenter:[_scrollView center]];
    
    [UIView animateWithDuration:0.4 animations:^{
        [_bigLabel setFrame:bigFrame];
        [_scrollView setFrame:scrollFrame];
        [_textView setFrame:textFrame];
        [_mapView setFrame:mapFrame];
        [_detailDescriptionLabel setFrame:detailFrame];
    } completion:^(BOOL finished) {
        // big label ends at the very bottom
        if (finished) {
            bigFrame.origin.y = totalFrame.size.height - bigFrame.size.height;
            usernameFrame.origin.y = bigFrame.origin.y - usernameFrame.size.height;
            [UIView animateWithDuration:0.5 animations:^{
                [_bigLabel setFrame:bigFrame];
                [_usernameLabel setFrame:usernameFrame];
            }];
        }
    }];
}

- (void)handleURL:(NSString*)url
{
    [self resizeWithoutMap];
    [self.mapView setHidden:YES];
    
    /*if ([TWLocDetailViewController imageExtension:url]) {
        [self openURL:[NSURL URLWithString:url]];
        return;
    }*/
    
    URLFetcher* fetcher = [[URLFetcher alloc] init];
    [fetcher fetch:url urlCallback:^(NSMutableString *html) {
        if (html != Nil) {
            [html appendString:@"\n"];
            [html appendString:[[self detailItem] tweet]];
            NSArray* arr = [self getURLs:html];
            html = [NSMutableString stringWithString:[arr componentsJoinedByString:@"\n\n"]];
            [[self detailItem] setOrigHTML:[arr componentsJoinedByString:@"\n"]];
            [self.textView setText:html];
            [self.scrollView setHidden:YES];
            [self findJPG:html theUrlStr:url];
        } else {
            [self.textView setText:@"CONNECTION FAILED"];
        }
        [[self activityView] stopAnimating];
        if ([URLProcessor imageExtensionURL:url]) {
            [self openURL:[NSURL URLWithString:url]];
            return;
        }
    }];
}

#pragma mark image
static NSString* lastURLopened = Nil;

// will get hit when the user chooses a URL from the text view
// should load the image
-(BOOL)openURL:(NSURL *)url
{
    lastURLopened = [url absoluteString];
    NSLog(@"detail URL:%@",lastURLopened);
    [self resizeWithoutMap];
    [self.mapView setHidden:YES];
    
    Tweet* originalTweet = [self detailItem];
    NSString* urlStr = [url description];
    if (![URLProcessor imageExtensionURL:urlStr]) {
        [self handleURL:urlStr]; // just grab the URL flat-up
    }
    
    [[self activityView] startAnimating];
    [[[self master] multipleOpQueue] addOperationWithBlock:^{
        NSData* picdata = [[self master] imageData:urlStr];
        if (picdata != Nil) {
            thisImageData = picdata;
            [self.scrollView setHidden:NO];
            [[[self master] updateQueue] addOperationWithBlock:^{
                UIImage *image = [[UIImage alloc] initWithData:picdata];
                if ([PhotoGetter isGIFtype:urlStr])
                    [PhotoGetter setupGIF:image iview:self.imageView sview:self.scrollView button:self.sizeButton rawData:picdata animate:YES];
                else
                    [PhotoGetter setupImage:image iview:self.imageView sview:self.scrollView button:self.sizeButton animate:YES];
                [[self master] keepTrackofReadURLs:urlStr];
                if (originalTweet != [self detailItem]) { // oops we moved !!
                    [[self activityView] stopAnimating];
                    return;
                }
                [self.view setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];
                [self.scrollView setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];

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
                    [[[self master] updateQueue] addOperationWithBlock:^{
                        [[self detailItem] setLocationFromPic:[NSNumber numberWithBool:YES]];
                        [[self detailItem] setLatitude:[NSNumber numberWithDouble:lat]];
                        [[self detailItem] setLongitude:[NSNumber numberWithDouble:lon]];
                        [[self detailItem] setUrl:urlStr];
                    }];
                } else {
                    [[[self master] updateQueue] addOperationWithBlock:^{
                        [[self detailItem] setUrl:urlStr];
                    }];
                }
                
                [[self activityView] stopAnimating];
            }];
            return;
        }
        [[[self master] updateQueue] addOperationWithBlock:^{
            PhotoGetter *getter = [[PhotoGetter alloc] init];
            [getter setIsRetinaDisplay:isRetinaDisplay];
            [getter getPhoto:url
                        into:self.imageView
                      scroll:self.scrollView
                   sizelabel:self.sizeButton
                    callback:^(float latitude, float longitude, NSString* timestamp, NSData* data) {
                        if (data == Nil) {
                            [[self activityView] stopAnimating];
                            return;
                        }
                        [self.view setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];
                        [self.scrollView setBackgroundColor: [self.sizeButton.titleLabel backgroundColor]];

                        NSInteger score = -1;
                        CGSize size = [[self.imageView image] size];
                        if (size.height > 900) score +=5;
                        if (size.width > 900) score += 5;
                        if (latitude > -900 && longitude > -900) score += 100;
                        [[self master] addScore:score toName:[originalTweet username]];
                        int picSize = MAX(size.height, size.width);
                        if ([PhotoGetter isGIFtype:url])
                            picSize *= 2;
                        if (latitude > -900 && longitude > -900) picSize += 5000;
                        __block bool hasVideo = NO;
                        [[URLProcessor getURLs:[originalTweet origHTML]] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            NSString* theURL = obj;
                            if ([URLProcessor isVideoFileURL:theURL]){
                                hasVideo = *stop = YES;
                            }
                        }];
                        if (hasVideo) picSize += 500;
                        [originalTweet setHasPicSize:[NSNumber numberWithInteger:picSize]];
                        [originalTweet setUserScore:[NSNumber numberWithInteger:[[self master] scoreForUser:[originalTweet username]]]];
                        
                        thisImageData = data;
                        [self.scrollView setHidden:NO];
                        if ([self master] != Nil) {
                            [[[self master] multipleOpQueue] addOperationWithBlock:^{
                                [[self master] imageData:data forURL:urlStr];
                                [[[self master].fetchedResultsController managedObjectContext] processPendingChanges];
                            }];
                        }
                        if (originalTweet != [self detailItem]) { // oops we moved !!
                            [[self activityView] stopAnimating];
                            return;
                        }
                        if (latitude > -900) {
                            [self resizeForMap];
                            [self displayMap:timestamp lat:latitude lon:longitude];
                            [[[self master] updateQueue] addOperationWithBlock:^{
                                [[self detailItem] setLocationFromPic:[NSNumber numberWithBool:YES]];
                                [[self detailItem] setLatitude:[NSNumber numberWithDouble:latitude]];
                                [[self detailItem] setLongitude:[NSNumber numberWithDouble:longitude]];
                                [[self detailItem] setUrl:urlStr];
                            }];
                            [[self master] keepTrackofReadURLs:urlStr];
                        } else {
                            [[[self master] updateQueue] addOperationWithBlock:^{
                                [[self detailItem] setUrl:urlStr];
                            }];
                            [[self master] keepTrackofReadURLs:urlStr];
                        }
                        
                        [[self activityView] stopAnimating];
                    }];
        }];
    }];
    return YES;
}

- (NSMutableArray*)getURLs:(NSString*)html
{
    return [URLProcessor getURLs:html];
}

- (void)findJPG:(NSMutableString*)html theUrlStr:(NSString*)url
{
    NSMutableArray* urlStrs = [URLProcessor getURLs:html];
    NSString* replace = [URLProcessor sortURLs:urlStrs fromUrl:url];
    [self.textView setText:html];
    [self checkForVideo:urlStrs];
    if ([[self detailItem] origHTML] == Nil ||
        [url rangeOfString:@".tumblr.com/image/"].location != NSNotFound) {
        [[[self master] updateQueue] addOperationWithBlock:^{
            [[self detailItem] setOrigHTML:html];
        }];
        [_infoButton setHidden:NO];
        [self setupPicturesCollection];
    }
    if (replace != Nil) {
        if ([URLProcessor imageExtensionURL:replace])
            [self openURL:[NSURL URLWithString:replace]];
        else
            [self handleURL:replace];
    } else {
        [[self activityView] stopAnimating];
    }
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
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
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
        //if (region.span.latitudeDelta < 0.1)
        //    delay = 1.0;
        if (region.span.latitudeDelta > 0.003)
            [self performSelector:@selector(setMapRegion:) withObject:Nil afterDelay:delay];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
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
            imageData = [self.master imageData:[[self detailItem] url]];
        if (imageData != Nil) {
            NSInteger score = 100;
            [[self master] addScore:score toName:[[self detailItem] username]];
            
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
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
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
    [_detailDescriptionLabel setHidden:YES];
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
    [[self activityLabel] addGestureRecognizer:statusTouch];
    
    [self addGestures:self.textView];
    [self addGestures:self.scrollView];
    [self addGestures:self.detailDescriptionLabel];
    [self addGestures:self.bigLabel];
    
    [self.textView setDelegate:self];
    
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
    
    if ([self detailItem] != Nil) {
        NSLog(@"started with a detail item defined");
    }
    doSomethingButton = [[UIBarButtonItem alloc]
                         initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                         target:self
                         action:@selector(doSomething:)];
    self.navigationItem.rightBarButtonItem = doSomethingButton;
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
    @try {
        UITextRange* selRange = [textView selectedTextRange];
        NSString* text = [textView text];
        NSInteger start = [textView offsetFromPosition:textView.beginningOfDocument toPosition:[selRange start]];
        NSInteger end = [textView offsetFromPosition:textView.beginningOfDocument toPosition:[selRange end]];
        if (start == 0 && end == 0) return;
        if (start == [text length]) return;
        while (start > 0 && [text characterAtIndex:start] != '\n')
            start --;
        start++;
        while (end < [text length] && [text characterAtIndex:end] != '\n')
            end++;
        end--;
        if (start == end) return;
        NSString* urlStr = [text substringWithRange:NSMakeRange(start, end-start)];
        NSLog(@"hit url = %@", urlStr);
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)addGestures:(UIView*)theView
{
    if (theView != _textView) {
        UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(handleTap:)];
        [tapGesture setDelaysTouchesEnded:YES];
        [theView addGestureRecognizer:tapGesture];
    }
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

#define ALERT_GETPRUNABLE (0x666)
#define ALERT_DOSOMETHING (0x12345)
#define ALERT_SAVEVIDEO (0x777)
#define ALERT_ADDTOLIST (0xadd17)
#define ALERT_REMOVEFROMLISTS (0xdead77)
#define ALERT_TAG_NULL (0x1)
#define DOSOMETHING_CANCEL @"CANCEL"
#define DOSOMETHING_DELETE @"DELETE Tweet"
#define DOSOMETHING_PRUNE @"add to pruner"
#define DOSOMETHING_REFRESH @"Refesh Tweet Links"
#define DOSOMETHING_FAVORITE @"Favorite Tweet"
#define DOSOMETHING_DOCUMENTS @"View Saved Movies"
#define DOSOMETHING_TWITTER @"View In Twitter"
#define DOSOMETHING_ADDLIST @"Add to newFolks list"
#define DOSOMETHING_ADDSPECIALLIST @"Add to special list"
#define DOSOMETHING_REMOVEFROMLIST @"Remove from all lists"
- (void)doSomething:(id)sender
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UIActionSheet* action = [[UIActionSheet alloc] initWithTitle:@"What to do?" delegate:self cancelButtonTitle:DOSOMETHING_CANCEL destructiveButtonTitle:DOSOMETHING_DELETE otherButtonTitles:DOSOMETHING_PRUNE, DOSOMETHING_REFRESH, DOSOMETHING_FAVORITE, DOSOMETHING_DOCUMENTS, DOSOMETHING_ADDLIST, DOSOMETHING_ADDSPECIALLIST, DOSOMETHING_REMOVEFROMLIST, DOSOMETHING_TWITTER, nil];
        [action setTag:ALERT_DOSOMETHING];
        [action showFromBarButtonItem:doSomethingButton animated:YES];
        return;
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"What to do?"
                                                    message:@"Delete, ReGrab, Favorite, etc?"
                                                   delegate:self
                                          cancelButtonTitle: DOSOMETHING_CANCEL
                                          otherButtonTitles: DOSOMETHING_PRUNE, DOSOMETHING_REFRESH, DOSOMETHING_FAVORITE, DOSOMETHING_DOCUMENTS, DOSOMETHING_ADDLIST, DOSOMETHING_ADDSPECIALLIST, DOSOMETHING_REMOVEFROMLIST, DOSOMETHING_TWITTER, nil];
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
                [[self master] deleteTweet:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_PRUNE] == NSOrderedSame) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    UIAlertView* alert = [[UIAlertView alloc] init];
                    [alert setTitle:@"Add to Prune Rules"];
                    [alert setTag:ALERT_GETPRUNABLE];
                    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
                    UITextField * alertTextField = [alert textFieldAtIndex:0];
                    [alertTextField setText:lastURLopened];
                    [alert setMessage:@"This string will cause the picture to prune every time"];
                    [alert addButtonWithTitle:@"Prune This URL"];
                    [alert addButtonWithTitle:@"KILL ALL PRUNE INFO"];
                    [alert setCancelButtonIndex:[alert addButtonWithTitle:DOSOMETHING_CANCEL]];
                    [alert setDelegate:self];
                    [alert show];
                }];
            } else if ([chosen compare:DOSOMETHING_REFRESH] == NSOrderedSame) {
                [[self master] refreshTweet:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_FAVORITE] == NSOrderedSame) {
                [[self master] favoriteTweet:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_DOCUMENTS] == NSOrderedSame) {
                [self doDocumentsView];
            } else if ([chosen compare:DOSOMETHING_TWITTER] == NSOrderedSame) {
                //[[self master] openInTwitter:[self detailItem]];
                [self openInTwitter:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_ADDLIST] == NSOrderedSame) {
                [self doAddList:NEWFOLKSLIST];
            } else if ([chosen compare:DOSOMETHING_ADDSPECIALLIST] == NSOrderedSame) {
                [self doAddList:SPECIALLIST];
            } else if ([chosen compare:DOSOMETHING_REMOVEFROMLIST] == NSOrderedSame) {
                [self removeFromLists];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
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
                [[self master] deleteTweet:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_REFRESH] == NSOrderedSame) {
                [[self master] refreshTweet:[self detailItem]];
            } else if ([chosen compare:DOSOMETHING_FAVORITE] == NSOrderedSame) {
                [[self master] favoriteTweet:[self detailItem]];
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
        } else if ([alertView tag] == ALERT_ADDTOLIST) {
            NSString* accountName = [alertView title];
            NSString* listName = [alertView buttonTitleAtIndex:buttonIndex];
            if (! [listName isEqualToString:DOSOMETHING_CANCEL]) {
                int start = (int)[listName rangeOfString:@"("].location;
                listName = [listName stringByReplacingCharactersInRange:NSMakeRange(start - 1, [listName length]+1-start) withString:@""];
                NSString* twitterName = [[alertView textFieldAtIndex:0] text];
                
                NSLog(@"adding user %@ to list %@ in account %@",twitterName,listName,accountName);
                [[self master] addUser:twitterName toListSlug:listName inAccount:accountName];
            }
        } else if ([alertView tag] == ALERT_REMOVEFROMLISTS) {
            NSString* listName = [alertView buttonTitleAtIndex:buttonIndex];
            if (! [listName isEqualToString:DOSOMETHING_CANCEL]) {
                NSString* twitterName = [[alertView textFieldAtIndex:0] text];
                NSLog(@"removing user %@ from all lists in all accounts",twitterName);
                [[self master] removeUserFromAllLists:twitterName];
            }
        } else if ([alertView tag] == ALERT_GETPRUNABLE) {
            NSString* chosen = [alertView buttonTitleAtIndex:buttonIndex];
            if ([chosen isEqualToString:@"Prune This URL"]) {
                NSString* prunable = [[alertView textFieldAtIndex:0] text];
                
                NSLog(@"adding prune action for %@",prunable);
                [self addToPrune:prunable];
            } else if ([chosen isEqualToString:@"KILL ALL PRUNE INFO"]) {
                [self killAllPruning];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
}

- (void)removeFromLists
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        Tweet* tweet = [self detailItem];
        UIAlertView* alert = [[UIAlertView alloc] init];
        [alert setTitle:@"Remove user from all lists"];
        NSInteger score = [[self master] scoreForUser:[tweet username]];
        [alert setMessage:[NSString stringWithFormat:@"NOTE: current score for %@ is %ld",[tweet username],(long)score]];
        [alert setTag:ALERT_REMOVEFROMLISTS];
        [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
        UITextField * alertTextField = [alert textFieldAtIndex:0];
        [alertTextField setText:[tweet username]]; // default to current twitterer
        [alert addButtonWithTitle:@"Remove From All lists"];
        [alert setCancelButtonIndex:[alert addButtonWithTitle:DOSOMETHING_CANCEL]];
        [alert setDelegate:self];
        [alert show];
    }];
}

typedef enum {NEWFOLKSLIST = 1, SPECIALLIST = 2} ListType;
- (void)doAddList:(ListType)theType
{
    NSDictionary* lists = Nil;
    NSString* accountName;
    if (theType == NEWFOLKSLIST) {
        accountName = [self master]->twitterAccountName;
        lists = [[self master] getTwitterLists:NO callback:^(NSDictionary *dict) {
            [self alertToAddToList:accountName lists:dict];
        }];
    } else if (theType == SPECIALLIST) {
        accountName = SPECIAL_TWITTER_ACCOUNT_NAME;
        lists = [[self master] specialGetTwitterLists:NO callback:^(NSDictionary *dict) {
            [self alertToAddToList:accountName lists:dict];
        }];
    } else return;
}

- (void)alertToAddToList:(NSString*)accountName lists:(NSDictionary*)lists
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        Tweet* tweet = [self detailItem];
        UIAlertView* alert = [[UIAlertView alloc] init];
        [alert setTitle:accountName];
        [alert setTag:ALERT_ADDTOLIST];
        [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
        UITextField * alertTextField = [alert textFieldAtIndex:0];
        [alertTextField setText:[tweet username]]; // default to current twitterer
        [lists enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [alert addButtonWithTitle:key];
        }];
        [alert setCancelButtonIndex:[alert addButtonWithTitle:DOSOMETHING_CANCEL]];
        [alert setDelegate:self];
        [alert show];
    }];
}


- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    //NSLog(@"endScrollDrag velocity=(%f,%f)",velocity.x,velocity.y);
    if (velocity.x > 5) {
        //[self.master nextTweet]; // want next new, not next going forwards
        [self.master nextTweet];
    }
    if (velocity.x < -5) {
        [self.master prevTweet];
    }
}

- (IBAction)touchedStatus:(id)sender
{
    [UIView animateWithDuration:0.2 animations:^{
        [self activityLabel].hidden = YES;
    }];
}

- (IBAction)handleTap:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if ([self master] != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        [[self master] keepTrackofReadURLs:obj];
                    }];
                [[self master] nextNewTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
- (IBAction)handleSwipeLeft:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if ([self master] != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        [[self master] keepTrackofReadURLs:obj];
                    }];
                [[self master] nextNewTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
- (IBAction)handleSwipeRight:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
            if ([self master] != Nil) {
                __block NSArray* pics = _pictures;
                if (pics && [pics count] > 1)
                    [pics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        [[self master] keepTrackofReadURLs:obj];
                    }];
                [[self master] prevTweet];
            } else
                NSLog(@"NIL MASTER IN tap");
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
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
            [UIView animateWithDuration:0.8 delay:0.01 options:UIViewAnimationOptionCurveLinear animations:^{
                self.scrollView.alpha = 0.0;
                self.textView.alpha = 1.0;
            } completion:^(BOOL finished) {
                self.scrollView.hidden = YES;
                self.scrollView.alpha = 1.0;
            }];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
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
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
- (IBAction)handleURLTouch:(UIGestureRecognizer *)gestureRecognizer
{
    @try {
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
            CGPoint location = [gestureRecognizer locationInView:[self textView]];
            UITextPosition* textBegining = [[self textView] beginningOfDocument];
            UITextPosition* textEnd = [[self textView] endOfDocument];
            UITextRange *trange = [_textView textRangeFromPosition:textBegining toPosition:textEnd];
            UITextPosition* position = [[self textView] closestPositionToPoint:location withinRange:trange];
            int start = (int)[[self textView] offsetFromPosition:textBegining toPosition:position];
            NSString* text = [[self textView] text];
            if ([text length] > start) {
                while (start > -1 && [text characterAtIndex:start] != '\n') start--;
                start = start+1;
                int end = start +1;
                while (end < [text length] && [text characterAtIndex:end] != '\n') end++;
                NSLog(@"Text length = %lu getting url at %d-%d",(unsigned long)[text length],start,end);
                NSString* urlStr = [text substringWithRange:NSMakeRange(start, end-start)] ;
                NSLog(@"PRESSED URL: %@",urlStr);
                [self openURL:[NSURL URLWithString:urlStr]];
            } else NSLog(@"start %d beyond text",start);
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
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
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"MEMORY warning detail view");
    [[self master] clearImageMemoryCache];
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
        
        bool isTumblr = [[[self detailItem] url] rangeOfString:@"tumblr.com"].location != NSNotFound ||
        [[[self detailItem] url] rangeOfString:@"tmblr.co"].location != NSNotFound;
        bool isGWIP = [[[self detailItem] url] rangeOfString:@"guyswithiphones.com"].location != NSNotFound;
        bool isInstagram = [[[self detailItem] url] rangeOfString:@"/instagr.am/"].location != NSNotFound;
        bool isOwly = [[[self detailItem] url] rangeOfString:@"/ow.ly/"].location != NSNotFound;
        bool isMoby = [[[self detailItem] url] rangeOfString:@"/moby.to/"].location != NSNotFound;
        bool isYouTube = [[[self detailItem] url] rangeOfString:@"youtube.com/"].location != NSNotFound ||
        [[[self detailItem] url] rangeOfString:@"/youtu.be/"].location != NSNotFound;
        NSArray* urls = [[[self detailItem] origHTML] componentsSeparatedByString:@"\n"];
        NSMutableOrderedSet* urlset = [NSMutableOrderedSet orderedSetWithArray:urls];
        //urlset = [urlset objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        NSMutableOrderedSet* finalset = [[NSMutableOrderedSet alloc] initWithCapacity:[urlset count]];
        [urlset enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* theURL = obj;
            if ([URLProcessor imageExtensionURL:theURL]) {
                if ([theURL rangeOfString:@"twimg.com/profile_images"].location != NSNotFound)
                    return;
                else if ([theURL rangeOfString:@"/hprofile"].location != NSNotFound)
                    return;
                else if (isTumblr) {
                    if ([theURL rangeOfString:@"media.tumblr.com"].location != NSNotFound &&
                        [theURL rangeOfString:@"/tumblr_"].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                } else if (isGWIP) {
                    if ([theURL rangeOfString:@"guyswithiphones.com/201"].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                } else if (isInstagram) {
                    if ([theURL rangeOfString:@"distilleryimage"].location != NSNotFound &&
                        [theURL rangeOfString:@".instagram.com/"].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                } else if (isOwly) {
                    if ([theURL rangeOfString:@"//static.ow.ly/"].location != NSNotFound &&
                        [theURL rangeOfString:@"/normal/"].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                } else if (isMoby) {
                    if ([theURL rangeOfString:@"mobypicture.com/"].location != NSNotFound &&
                        [theURL rangeOfString:@"_view."].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                } else if (isYouTube) {
                    if ([theURL rangeOfString:@"/hqdefault."].location != NSNotFound)
                        [finalset addObject:theURL];
                    return;
                }
                [finalset addObject:theURL];
            }
            return;
        }];
        if (isTumblr)
            urlset = [self removeTumblrDups:finalset];
        else
            urlset = [self pruneIdiots:finalset];
        NSLog(@"THE SET OF PICS:\n%@",[urlset description]);
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if ([urlset count] > 1) {
                [_picCollection setHidden:NO];
                [_picButton setHidden:YES];
                _pictures = [urlset array];
                [_picCollection reloadData];
                [_picCollection setNeedsDisplay];
                [_picCollection setNeedsLayout];
                [_picCollection setNeedsUpdateConstraints];
                [_picCollection selectItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                [_picCollection scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
                [_picButton setTitle:[NSString stringWithFormat:@"%lu Pics",(unsigned long)[_pictures count]] forState:UIControlStateNormal];
                [_picButton setHidden:NO];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [_picCollection setHidden:YES];
                }];
            }
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
static NSMutableArray* pruneMe = Nil;
- (void)addToPrune:(NSString*)str
{
    if (str == Nil || [str length] < 5)
        return;
    @try {
        if (pruneMe == Nil) {
            pruneMe = [[NSMutableArray alloc] initWithCapacity:10];
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"URLprune.txt"];
            //read the whole file as a single string
            NSData *content = [NSData dataWithContentsOfFile:fileName];
            NSString* jsonString = [[NSString alloc] initWithBytes:[content bytes] length:[content length] encoding:NSUTF8StringEncoding];
            NSArray* fileStrings = [jsonString componentsSeparatedByString:@"\n"];
            [fileStrings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([(NSString*)obj length] > 4)
                    [pruneMe addObject:obj];
            }];
        }
        __block BOOL found = NO;
        [pruneMe enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([str rangeOfString:obj].location != NSNotFound)
                *stop = found = YES;
        }];
        if (!found)
            [pruneMe addObject:str];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"URLprune.txt"];
        
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        NSError *error;
        NSString* pruneString = [pruneMe componentsJoinedByString:@"\n"];
        [pruneString writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:&error];
        NSLog(@"WROTE prunes=%@\n%@",error,pruneString);
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
- (void)killAllPruning
{
    @try {
        pruneMe = [[NSMutableArray alloc] initWithCapacity:10];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"URLprune.txt"];
        //delete file if it exists
        if([[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] removeItemAtPath:fileName error:Nil];
        NSLog(@"Killed pruning file %@",fileName);
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}
- (NSMutableOrderedSet*)pruneIdiots:(NSMutableOrderedSet*)urlset
{
    NSMutableOrderedSet* retset = [[NSMutableOrderedSet alloc] initWithCapacity:1];
    @try {
        if (pruneMe == Nil) {
            pruneMe = [[NSMutableArray alloc] initWithCapacity:10];
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"URLprune.txt"];
            //read the whole file as a single string
            NSData *content = [NSData dataWithContentsOfFile:fileName];
            NSString* jsonString = [[NSString alloc] initWithBytes:[content bytes] length:[content length] encoding:NSUTF8StringEncoding];
            NSArray* fileStrings = [jsonString componentsSeparatedByString:@"\n"];
            [fileStrings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([(NSString*)obj length] > 4)
                    [pruneMe addObject:obj];
            }];
            NSLog(@"Read prunings:\n%@",pruneMe);
        }
        [urlset enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* theURL = obj;
            __block bool bad = NO;
            if (pruneMe != Nil) [pruneMe enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([(NSString*)obj length] > 4 && [theURL rangeOfString:obj].location != NSNotFound) {
                    *stop = bad = YES;
                    NSLog(@"pruned %@",theURL);
                }
            }];
            if (!bad)
                [retset addObject:theURL];
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
    return retset;
}
- (NSMutableOrderedSet*)removeTumblrDups:(NSMutableOrderedSet*)urlset
{
    NSMutableOrderedSet* retset = [[NSMutableOrderedSet alloc] initWithCapacity:1];
    @try {
        [urlset enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
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
                    [retset enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
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
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
    return retset;
}
- (IBAction)picturesButtonHit:(id)sender
{
    [_picCollection setHidden:(![_picCollection isHidden])];
}

static NSString* videoURL = Nil;

- (void)checkForVideo:(NSArray*)urls
{
    @try {
        videoURL = Nil;
        if (urls == Nil) {
            [_videoButton setHidden:YES];
            [_previewVideoButton setHidden:YES];
            return;
        }
        __block bool hasVideo = NO;
        [urls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* theURL = obj;
            if ([URLProcessor isVideoFileURL:theURL]){
                hasVideo = *stop = YES;
                videoURL = theURL;
                NSLog(@"VIDEO URL = %@",theURL);
            }

        }];
        [_videoButton setHidden:(!hasVideo)];
        [_previewVideoButton setHidden:(!hasVideo)];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (IBAction)videoButtonHit:(id)sender
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"SAVE VIDEO" message:[NSString stringWithFormat:@"Save the %@ video?",videoURL] delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES, save", nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [[alert textFieldAtIndex:0] setText:[[self detailItem] username]];
    alert.tag = ALERT_SAVEVIDEO;
    [alert show];
}
NSTimer* videoTimer = Nil;
- (IBAction)previewVideoButtonHit:(id)sender
{
    @try {
        NSLog(@"PREVIEW VIDEO URL = %@",videoURL);
        UIStoryboard *webviewSB = [UIStoryboard storyboardWithName:@"WebViewController"
                                                            bundle:Nil];
        WebViewController *webView = [webviewSB instantiateInitialViewController];
        [self presentViewController:webView animated:YES completion:^{
            [webView loadURL:videoURL];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)saveVideo:(NSString*)additionalName
{
    @try {
        [[self master] addScore:100 toName:[[self detailItem] username]];

        NSLog(@"Needing to save %@ to file", videoURL);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString* lastNamePart;
        NSMutableString* realFileName = [[NSMutableString alloc] initWithString:videoURL.lastPathComponent];
        NSInteger questionMarkLocation = [realFileName rangeOfString:@"?"].location;
        if (questionMarkLocation != NSNotFound) {
            [realFileName deleteCharactersInRange:NSMakeRange(questionMarkLocation, [realFileName length]-questionMarkLocation)];
        }
        lastNamePart = [NSString stringWithFormat:@"%@ %@%@", additionalName,
                        realFileName, @".mp4"];
        NSString* filename = [documentsDirectory
                              stringByAppendingPathComponent:
                              lastNamePart];
        NSLog(@"the filename will be %@",filename);
        
        [[self activityView] startAnimating];
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
                  
                  [[[self master] queueLabel] setText:filename];
                  [[self activityView] stopAnimating];
              } else { // not complete
                  float datasize = dataSize / 1024.0 / 1024.0;
                  [[[self master] queueLabel] setText:[NSString stringWithFormat:@"%.2f MB",datasize]];
              }
          }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)doDocumentsView
{
    @try {
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
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)openInTwitter:(Tweet*)tweet
{
    @try {
        NSString* tweetID = [[tweet tweetID] description];
        NSString* tweetuser = [tweet username];
        NSString* url = [NSString stringWithFormat:@"https://twitter.com/%@/status/%@", tweetuser, tweetID];
        NSLog(@"twitter open: %@", url);
        UIStoryboard *webviewSB = [UIStoryboard storyboardWithName:@"WebViewController"
                                                            bundle:Nil];
        WebViewController *webView = [webviewSB instantiateInitialViewController];
        [self presentViewController:webView animated:YES completion:^{
            [webView shiftBelowButton];
            [webView loadURL:url];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}


#pragma mark Collection View Data Source
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        TWLocPicCollectionCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"picture" forIndexPath:indexPath];
        int idx = (int)[indexPath row];
        //[[cell image] setImage:[_pictures objectAtIndex:idx]];
        [[cell theImage] setImage:[[self master] redX]];
        NSString* urlstr = [_pictures objectAtIndex:idx];
        if (urlstr == Nil)
            return cell;
        [[[self master] multipleOpQueue] addOperationWithBlock:^{
            [self collectionCellPicture:urlstr imageView:[cell theImage]];
        }];
        return cell;
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
    return Nil;
}

- (void)collectionCellPicture:(NSString*)urlstr imageView:(UIImageView*)iview
{
    @try {
        NSData* picdata = [[self master] imageData:urlstr];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            PhotoGetter* getter = [[PhotoGetter alloc] init];
            if (picdata == Nil) {
                [getter getPhoto:[NSURL URLWithString:urlstr]
                            into:iview
                          scroll:Nil
                       sizelabel:Nil
                        callback:^(float latitude, float longitude, NSString *timestamp, NSData *imageData) {
                            [[[self master] multipleOpQueue] addOperationWithBlock:^{
                                [[self master] imageData:imageData forURL:urlstr];
                                [[self master] keepTrackofReadURLs:urlstr];
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
                                  rawData:picdata animate:NO];
                else
                    [PhotoGetter setupImage:image
                                      iview:iview
                                      sview:Nil
                                     button:Nil animate:NO];
                [[self master] keepTrackofReadURLs:urlstr];
            }
            
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
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
        int idx = (int)[indexPath row];
        NSLog(@"selected picture %d",idx);
        [[self sizeButton] setEnabled:YES];
        [[self sizeButton] setHidden:NO];
        
        [self openURL:[NSURL URLWithString:[_pictures objectAtIndex:idx]]];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}

@end
