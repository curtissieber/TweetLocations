//
//  PhotoGetter.m
//  tryScroll
//
//  Created by Curtis Sieber on 10/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import "PhotoGetter.h"
#import "AnimatedGif.h"

@implementation PhotoGetter

@synthesize photoData, imageView, sizeButton, scrollView;

- (void)setIsRetinaDisplay:(BOOL)isretina
{
    self->isRetinaDisplay = isretina;
}

- (void)getPhoto:(NSURL*)url
            into:(UIImageView*)iview
          scroll:(UIScrollView*)sview
       sizelabel:(UIButton*)ibutton
        callback:(PhotoCallback)theCallback
{
    self->isGIF = [PhotoGetter isGIFtype:url];
    [self setScrollView:sview];
    [self setImageView:iview];
    [self setSizeButton:ibutton];
    self->callback = theCallback;
    [self getPhoto:url];
}

+ (bool)isGIFtype:(id)url
{
    NSString* urlstr;
    if ([[url class] isSubclassOfClass:[NSURL class]])
        urlstr = [(NSURL*)url absoluteString];
    else if ([[url class] isSubclassOfClass:[NSString class]])
        urlstr = url;
    else
        return NO;
    NSString* ext = [urlstr pathExtension];
    if ([ext localizedCaseInsensitiveCompare:@"gif"] == NSOrderedSame)
        return YES;
    return NO;
}

- (void)getPhoto:(NSURL*)url
{
    // Create the request.
    NSURLRequest *theRequest=[NSURLRequest 
                              requestWithURL:url                                                                    
                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                              timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data
    NSLog(@"Starting connection to %@",[url description]);
    NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        photoData = [NSMutableData data];
        //NSLog(@"initialized receivedData structure");
    } else {
        // Inform the user that the connection failed.
        //NSLog(@"Connection to %@ failed", url);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    //NSLog(@"setting string empty for received photo data");
    [photoData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    //NSLog(@"appending photo data of size %d",[data length]);
    [photoData appendData:data];
}
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    [photoData setLength:0];
    
    // inform the user
    NSLog(@"Connection failed for photo data! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if (self->callback) {
        callback(-999, -999, @"no time", Nil);
    }
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    @try {
        // do something with the data
        // receivedData is declared as a method instance elsewhere
        //NSLog(@"Succeeded! Received %d bytes of photo data",[photoData length]);
        
        CGImageSourceRef  source = CGImageSourceCreateWithData((__bridge CFDataRef)photoData, NULL);
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
        //NSLog(@"lat=%f Lon=%f",lat,lon);
        
        UIImage *image = [[UIImage alloc] initWithData:photoData];
        
        if (self->isGIF)
            [PhotoGetter setupGIF:image iview:imageView sview:scrollView button:sizeButton rawData:photoData animate:YES];
        else
            [PhotoGetter setupImage:image iview:imageView sview:scrollView button:sizeButton animate:YES];
                
        if (self->callback) {
            callback(lat, lon, timestamp, photoData);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

+ (void)setupImage:(UIImage*)image
             iview:(UIImageView*)iview
             sview:(UIScrollView*)sview
            button:(UIButton*)button
           animate:(BOOL)doAnimate
{
    if (sview == Nil || button == Nil) {
        [iview setImage:image];
        [iview setAnimationImages: Nil];
        [iview setAnimationDuration:0];
        [iview stopAnimating];
        return;
    }
    [sview setContentScaleFactor:1];
    [sview setContentOffset:CGPointMake(0, 0)];
    [sview setTransform:CGAffineTransformIdentity];
    CGRect frame = [iview frame];
    frame.origin.x = frame.origin.y = 0;
    //frame.size = [image size];
    [iview setFrame:frame];
    [iview setTransform:CGAffineTransformIdentity];
    [iview setContentMode:UIViewContentModeScaleAspectFit];
    
    //[iview setImage:image];
    if (doAnimate) [UIView transitionWithView:sview
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        iview.image = image;
                        [iview setAnimationImages: Nil];
                        [iview setAnimationDuration:0];
                        [iview stopAnimating];
                    }
                    completion:Nil];
    else {
        iview.image = image;
        [iview setAnimationImages: Nil];
        [iview setAnimationDuration:0];
        [iview stopAnimating];
    }
    
    //[iview sizeToFit];
    [sview setContentScaleFactor:1];
    [sview setContentOffset:CGPointMake(0, 0)];
    [sview setTransform:CGAffineTransformIdentity];
    float scale = 1.0;
    CGSize imageSize = [iview frame].size;
    CGSize scrollSize = [sview frame].size;
    
    [sview setContentSize:imageSize];
    scale = scrollSize.width / imageSize.width;
    if (scrollSize.height / imageSize.height < scale)
        scale = scrollSize.height / imageSize.height;
    [sview setContentScaleFactor:scale];
    CGPoint offset = CGPointMake((scrollSize.width-imageSize.width*scale)/2,
                                 (scrollSize.height-imageSize.height*scale)/2);
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    transform = CGAffineTransformTranslate(transform, offset.x, offset.y);
    [sview setTransform:transform];
    //[sview setClipsToBounds:YES];
    [sview setNeedsDisplay];
    //NSLog(@"isize %0.1f %0.1f ssize %0.1f %0.1f scale %0.1f offset %0.1f %0.1f",
    //      imageSize.width,imageSize.height,
    //      scrollSize.width, scrollSize.height,
    //      scale,
    //     offset.x, offset.y);
    
    int height = [image size].height;
    int width = [image size].width;
    NSString *sizetxt = [NSString stringWithFormat:@"[%d x %d]",height,width];
    [button setTitle:sizetxt forState:UIControlStateNormal];
    [button setTitle:@"SAVING PICTURE" forState:UIControlStateSelected];
    [button setTitle:@"SAVING PICTURE" forState:UIControlStateHighlighted];
    if (height > 900 || width > 900)
        [button.titleLabel setBackgroundColor:[UIColor cyanColor]];
    else
        [button.titleLabel setBackgroundColor:[UIColor whiteColor]];
}

#define SIMPLE_GIFS

+ (void)setupGIF:(UIImage*)image
             iview:(UIImageView*)iview
             sview:(UIScrollView*)sview
            button:(UIButton*)button
           rawData:(NSData*)data
         animate:(BOOL)doAnimate
{
    if (sview == Nil || button == Nil) {
#ifdef SIMPLE_GIFS
        float frameTime = 0;
        NSArray* frames = [PhotoGetter gifFrames:data runTime:&frameTime];
        if (frames != Nil && [frames count] > 0) {
            [iview setImage: [frames objectAtIndex:0]];
            [iview setAnimationImages: frames];
            [iview setAnimationDuration:frameTime];
            [iview startAnimating];
        }
        return;
#else
        // GIF-special section
        AnimatedGif* animate = [[AnimatedGif alloc] init];
        [animate decodeGIF:data];
        UIImageView *tempImageView = [animate getAnimation];
        
        [iview setImage: [tempImageView image]];
        [iview setAnimationImages: [tempImageView animationImages]];
        [iview setAnimationDuration:[tempImageView animationDuration]];
        [iview startAnimating];
        return;
#endif
    }
    [sview setContentScaleFactor:1];
    [sview setContentOffset:CGPointMake(0, 0)];
    [sview setTransform:CGAffineTransformIdentity];
    CGRect frame = [iview frame];
    frame.origin.x = frame.origin.y = 0;
    //frame.size = [image size];
    [iview setFrame:frame];
    [iview setTransform:CGAffineTransformIdentity];
    [iview setContentMode:UIViewContentModeScaleAspectFit];

#ifdef SIMPLE_GIFS
    if (doAnimate) [UIView transitionWithView:sview
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        float frameTime = 0;
                        NSArray* frames = [PhotoGetter gifFrames:data runTime:&frameTime];
                        if (frames != Nil && [frames count] > 0) {
                            [iview setImage: [frames objectAtIndex:0]];
                            [iview setAnimationImages: frames];
                            [iview setAnimationDuration:frameTime];
                            [iview startAnimating];
                        }
                    }
                    completion:Nil];
    else {
        float frameTime = 0;
        NSArray* frames = [PhotoGetter gifFrames:data runTime:&frameTime];
        if (frames != Nil && [frames count] > 0) {
            [iview setImage: [frames objectAtIndex:0]];
            [iview setAnimationImages: frames];
            [iview setAnimationDuration:frameTime];
            [iview startAnimating];
        }
    }
#else
    // GIF-special section
    AnimatedGif* animate = [[AnimatedGif alloc] init];
    [animate decodeGIF:data];
    UIImageView *tempImageView = [animate getAnimation];
    
    //[iview setImage:image];
    if (doAnimate) [UIView transitionWithView:sview
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [iview setImage: [tempImageView image]];
                        //[iview sizeToFit];
                        [iview setAnimationImages: [tempImageView animationImages]];
                        [iview setAnimationDuration:[tempImageView animationDuration]];
                        [iview startAnimating];
                    }
                    completion:Nil];
    else
    {
        [iview setImage: [tempImageView image]];
        //[iview sizeToFit];
        [iview setAnimationImages: [tempImageView animationImages]];
        [iview setAnimationDuration:[tempImageView animationDuration]];
        [iview startAnimating];
    }
#endif
    //[iview sizeToFit];
    [sview setContentScaleFactor:1];
    [sview setContentOffset:CGPointMake(0, 0)];
    [sview setTransform:CGAffineTransformIdentity];
    float scale = 1.0;
    CGSize imageSize = [iview frame].size;
    CGSize scrollSize = [sview frame].size;
    
    [sview setContentSize:imageSize];
    scale = scrollSize.width / imageSize.width;
    if (scrollSize.height / imageSize.height < scale)
        scale = scrollSize.height / imageSize.height;
    [sview setContentScaleFactor:scale];
    CGPoint offset = CGPointMake((scrollSize.width-imageSize.width*scale)/2,
                                 (scrollSize.height-imageSize.height*scale)/2);
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    transform = CGAffineTransformTranslate(transform, offset.x, offset.y);
    [sview setTransform:transform];
    //[sview setClipsToBounds:YES];
    [sview setNeedsDisplay];
    //NSLog(@"isize %0.1f %0.1f ssize %0.1f %0.1f scale %0.1f offset %0.1f %0.1f",
    //      imageSize.width,imageSize.height,
    //      scrollSize.width, scrollSize.height,
    //      scale,
    //      offset.x, offset.y);
    
    int height = [image size].height;
    int width = [image size].width;
    NSString *sizetxt = [NSString stringWithFormat:@"[%d x %d]",height,width];
    [button setTitle:sizetxt forState:UIControlStateNormal];
    [button setTitle:@"SAVING PICTURE" forState:UIControlStateSelected];
    [button setTitle:@"SAVING PICTURE" forState:UIControlStateHighlighted];
    if (height > 300 || width > 300)
        [button.titleLabel setBackgroundColor:[UIColor cyanColor]];
    else
        [button.titleLabel setBackgroundColor:[UIColor whiteColor]];
}

+ (NSArray*)gifFrames:(NSData*)data runTime:(float*)theTime
{
    NSMutableArray *frames = nil;
    *theTime = 0.0;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (src) {
        size_t l = CGImageSourceGetCount(src);
        frames = [NSMutableArray arrayWithCapacity:l];
        for (size_t i = 0; i < l; i++) {
            CGImageRef img = CGImageSourceCreateImageAtIndex(src, i, NULL);
            if (img) {
                [frames addObject:[UIImage imageWithCGImage:img]];
                CGImageRelease(img);
            }
            NSDictionary* imgDict = (__bridge NSDictionary *)(CGImageSourceCopyPropertiesAtIndex(src, i, NULL));
            if (imgDict != Nil) {
                NSDictionary *frameProperties = [imgDict objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
                if (frameProperties != Nil) {
                    NSNumber *delayTime = [frameProperties objectForKey:(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
                    if (delayTime != Nil)
                        *theTime += [delayTime floatValue];
                }
            }
        }
        CFRelease(src);
    }
    return frames;
}

@end
