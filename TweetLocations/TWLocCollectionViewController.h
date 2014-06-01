//
//  TWLocCollectionViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 1/26/14.
//  Copyright (c) 2014 Curtsybear.com. All rights reserved.
//

#import "TWLocDetailViewController.h"
#import "TWLocPicCollectionCell.h"
#import "TWLocBigDetailViewController.h"
#import "TWLocMasterViewController.h"

@interface TWLocCollectionViewController : TWLocDetailViewController <UICollectionViewDataSource,
        UICollectionViewDelegate>

@property (strong, nonatomic) TWLocMasterViewController* master;
@property (strong, nonatomic) IBOutlet UICollectionView* collectionView;
@property (strong, nonatomic) IBOutlet UIImageView* imageView;
@property (strong, nonatomic) TWLocBigDetailViewController* bigDetail;

@end
