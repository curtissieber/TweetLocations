//
//  TWLocBigDetailViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "TWLocMasterViewController.h"
#import "Tweet.h"

#import "TWLocDetailViewController.h"

@interface TWLocBigDetailViewController : TWLocDetailViewController
            <UISplitViewControllerDelegate, UIScrollViewDelegate, UIAlertViewDelegate,
            UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegate,
            UITextViewDelegate>
{
                NSData* thisImageData;
}
@property (retain, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (retain, nonatomic) IBOutlet UILabel *usernameLabel;
@property (retain, nonatomic) IBOutlet MKMapView *mapView;
@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet UILabel *bigLabel;
@property (retain, nonatomic) IBOutlet UITextView *textView;
@property (retain, nonatomic) IBOutlet UIButton *sizeButton;

@property (retain, nonatomic) IBOutlet UIButton* infoButton;
@property (retain, nonatomic) IBOutlet UIButton* videoButton;
@property (retain, nonatomic) IBOutlet UIButton* previewVideoButton;
@property (retain, nonatomic) IBOutlet UIButton* picButton;
@property (retain, nonatomic) IBOutlet UICollectionView* picCollection;
@property (retain, nonatomic) NSArray *pictures;

- (IBAction)touchedStatus:(id)sender;
- (IBAction)picturesButtonHit:(id)sender;
- (IBAction)videoButtonHit:(id)sender;
- (IBAction)previewVideoButtonHit:(id)sender;
- (IBAction)infoButtonHit:(id)sender;
@end
