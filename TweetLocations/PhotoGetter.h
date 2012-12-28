//
//  PhotoGetter.h
//  tryScroll
//
//  Created by Curtis Sieber on 10/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^PhotoCallback)(float latitude, float longitude, NSString* timestamp, NSData* imageData);

@interface PhotoGetter : NSObject {
    NSMutableData   *photoData;
    UIScrollView    *scrollView;
    UIImageView     *imageView;
    UIButton        *sizeButton;
    bool            isRetinaDisplay;
    bool            isGIF;
    PhotoCallback   callback;
}

@property (atomic, retain) NSMutableData   *photoData;
@property (atomic, retain) UIScrollView    *scrollView;
@property (atomic, retain) UIImageView     *imageView;
@property (atomic, retain) UIButton        *sizeButton;

+ (bool)isGIFtype:(id)url;
- (void)getPhoto:(NSURL*)url
            into:(UIImageView*)iview
          scroll:(UIScrollView*)sview
       sizelabel:(UIButton*)ibutton
        callback:(PhotoCallback)theCallback;
- (void)getPhoto:(NSURL*)url;
- (void)setIsRetinaDisplay:(BOOL)isretina;
+ (void)setupImage:(UIImage*)image
             iview:(UIImageView*)iview
             sview:(UIScrollView*)sview
            button:(UIButton*)button;
+ (void)setupGIF:(UIImage*)image
             iview:(UIImageView*)iview
             sview:(UIScrollView*)sview
            button:(UIButton*)button
           rawData:(NSData*)data;

@end
