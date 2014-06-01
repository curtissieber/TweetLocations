//
//  TWLocCollectionViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 1/26/14.
//  Copyright (c) 2014 Curtsybear.com. All rights reserved.
//

#import "TWLocCollectionViewController.h"
#import "TWLocPicCollectionCell.h"
#import "PhotoGetter.h"
#import "URLFetcher.h"
#import "WebViewController.h"
#import "Tweet.h"

@interface TWLocCollectionViewController ()

@end

@implementation TWLocCollectionViewController

#pragma mark Collection View Data Source
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        TWLocPicCollectionCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PictureCell" forIndexPath:indexPath];
        int idx = (int)[indexPath row];
        [[cell theImage] setImage:[[self master] redX]];
        Tweet* tweet = [[self master] tweetAtIndex:idx];
        NSString* urlstr = [[[tweet url] componentsSeparatedByString:@"\n"] firstObject];
        if (urlstr == Nil)
            return cell;
        [[[self master] multipleOpQueue] addOperationWithBlock:^{
            [self collectionCellPicture:urlstr imageView:[cell theImage] tweet:tweet cell:cell];
        }];
        return cell;
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
    return Nil;
}

- (void)collectionCellPicture:(NSString*)urlstr imageView:(UIImageView*)iview tweet:(Tweet*)tweet cell:(TWLocPicCollectionCell*)cell
{
    @try {
        NSData* picdata = [[self master] imageData:urlstr];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            PhotoGetter* getter = [[PhotoGetter alloc] init];
            if (picdata == Nil) {
                NSLog(@"no data for image %@ at %ld",urlstr,(long)[[[self master] fetchedResultsController] indexPathForObject:tweet].row);
                [getter getPhoto:[NSURL URLWithString:urlstr]
                            into:iview
                          scroll:Nil
                       sizelabel:Nil
                        callback:^(float latitude, float longitude, NSString *timestamp, NSData *imageData) {
                            [[[self master] multipleOpQueue] addOperationWithBlock:^{
                                [[self master] imageData:imageData forURL:urlstr];
                                [self collectionCellPicture:urlstr imageView:iview tweet:tweet cell:cell];
                            }];
                        }];
            } else {
                UIImage *image = [[UIImage alloc] initWithData:picdata];
                CGSize imageSize = [image size];
                
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
                [self doMainBlock:^{
                    if ([[tweet locationFromPic] boolValue])
                        [cell setBackgroundColor:[UIColor redColor]];
                    else if (imageSize.height > 1023 || imageSize.width > 1023)
                        [cell setBackgroundColor:[UIColor blueColor]];
                    else
                        [cell setBackgroundColor:[UIColor blackColor]];
                }];
            }
            
        }];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    @try {
        if ([self master] == Nil)
            return 0;
        if ([[self master] fetchedResultsController] == Nil)
            return 0;
        if ([[[self master] fetchedResultsController] fetchedObjects] == Nil)
            return 0;
        return [[[[self master] fetchedResultsController] fetchedObjects] count];
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}

static NSString* videoURL = Nil;
- (void)checkForVideo:(NSSet*)urls
{
    @try {
        videoURL = Nil;
        if (urls == Nil) {
            return;
        }
        __block bool hasVideo = NO;
        [urls enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            NSString* theURL = obj;
            if ([URLProcessor isVideoFileURL:theURL]){
                hasVideo = *stop = YES;
                videoURL = theURL;
                NSLog(@"VIDEO URL = %@",theURL);
                
                NSLog(@"PREVIEW VIDEO URL = %@",videoURL);
                UIStoryboard *webviewSB = [UIStoryboard storyboardWithName:@"WebViewController"
                                                                    bundle:Nil];
                WebViewController *webView = [webviewSB instantiateInitialViewController];
                [self presentViewController:webView animated:YES completion:^{
                    [webView loadURL:videoURL];
                }];
                
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

#pragma mark Collection View Delegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        int idx = (int)[indexPath row];
        NSLog(@"selected picture %d",idx);
        //[[self sizeButton] setEnabled:YES];
        //[[self sizeButton] setHidden:NO];
        
        //[self openURL:[NSURL URLWithString:[_pictures objectAtIndex:idx]]];
        Tweet* tweet = [[self master] tweetAtIndex:idx];
        if (tweet != Nil) {
            NSLog(@"tweet:\n%@",tweet);
            
            [self checkForVideo:[NSSet setWithArray:[[tweet origHTML] componentsSeparatedByString:@"\n"]]];
            
            TWLocPicCollectionCell* cell = (TWLocPicCollectionCell*)[collectionView cellForItemAtIndexPath:indexPath];
            //UIImage* image = [[cell theImage] image];
            NSString* url = [[[tweet url] componentsSeparatedByString:@"\n"] firstObject];;
            NSData* imageData = [[self master] imageData:url];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            if (imageData != Nil && image != Nil) [self doMainBlock:^{
                if ([PhotoGetter isGIFtype:url])
                    [PhotoGetter setupGIF:image iview:[self imageView] sview:Nil button:Nil rawData:imageData animate:NO];
                else
                    [PhotoGetter setupImage:image iview:[self imageView] sview:Nil button:Nil animate:NO];
                if ([PhotoGetter isGIFtype:url])
                    [PhotoGetter setupGIF:image iview:[cell theImage] sview:Nil button:Nil rawData:imageData animate:NO];
                else
                    [PhotoGetter setupImage:image iview:[cell theImage] sview:Nil button:Nil animate:NO];
                [[self imageView] setHidden:NO];
                [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
            }];
            else [self doMainBlock:^{
                [tweet setHasBeenRead:[NSNumber numberWithBool:NO]];
                [tweet setOrigHTML:Nil];
                TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet index:indexPath masterViewController:[self master] replaceURL:Nil];
                [top setQueuePriority:NSOperationQueuePriorityLow];
                [TWLocMasterViewController incrementTasks];
                [[[self master] multipleOpQueue] addOperation:top];
                [[[self master] multipleOpQueue] setSuspended:NO];
                
                PhotoGetter* getter = [[PhotoGetter alloc] init];
                [getter getPhoto:[NSURL URLWithString:url]
                            into:[self imageView]
                          scroll:Nil
                       sizelabel:Nil
                        callback:^(float latitude, float longitude, NSString *timestamp, NSData *imageData) {
                            [[[self master] multipleOpQueue] addOperationWithBlock:^{
                                [[self master] imageData:imageData forURL:url];
                                [self collectionCellPicture:url imageView:[cell theImage] tweet:tweet cell:cell];
                            }];
                        }];
            }];
        }
    } @catch (NSException *ee) {
        NSLog(@"Exception [%@] %@\n%@\n",[ee name],[ee reason],[NSThread callStackSymbols] );
    }
}

#pragma mark ViewThings

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
    [[self imageView] setHidden:YES];
        
    UITapGestureRecognizer* statusTouch = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(touchedStatus:)];
    [statusTouch setCancelsTouchesInView:YES];
    [statusTouch setDelaysTouchesBegan:YES];
    [[self activityLabel] addGestureRecognizer:statusTouch];
    
    UITapGestureRecognizer* imageTouch = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(touchedImage:)];
    [statusTouch setCancelsTouchesInView:YES];
    [statusTouch setDelaysTouchesBegan:YES];
    [[self imageView] addGestureRecognizer:imageTouch];

}

- (IBAction)touchedStatus:(id)sender
{
    [UIView animateWithDuration:0.2 animations:^{
        [self activityLabel].hidden = YES;
    }];
}

- (IBAction)touchedImage:(id)sender
{
    [[self imageView] setHidden:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    @try {
        if ([[segue identifier] isEqualToString:@"CollectionSelection"]) {
            NSIndexPath *indexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
            Tweet *object = [[self.master fetchedResultsController] objectAtIndexPath:indexPath];
            [[self.master updateQueue] addOperationWithBlock:^{
                [object setHasBeenRead:[NSNumber numberWithBool:YES]];
                [self.master keepTrackofReadURLs:[object url]];
            }];
            [[segue destinationViewController] setDetailItem:object];
            self.bigDetail = [segue destinationViewController];
            [self.bigDetail setMaster:self.master];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    [[self.master updateQueue] addOperationWithBlock:^{
        @try {
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSManagedObjectContext *context = [self.master.fetchedResultsController managedObjectContext];
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    }];
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
