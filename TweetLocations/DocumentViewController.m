//
//  DocumentViewController.m
//  PasteParse
//
//  Created by Curtis Sieber on 10/7/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import "DocumentViewController.h"

@interface DocumentViewController ()

@end

@implementation DocumentCell

@end

@implementation DocumentViewController

@synthesize theData, filesizes;

- (IBAction)doDone:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:Nil];
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [theTableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [[cell textLabel] setText:[theData objectAtIndex:[indexPath row]]];
    long long fsize = [[filesizes objectAtIndex:[indexPath row]] longLongValue];
    [[cell detailTextLabel] setText:[NSString stringWithFormat:@"%.2f MB", fsize/1024.0/1024.0]];
    
    fsize = 0;
    for (int i=0; i < [filesizes count]; i++)
        fsize += [[filesizes objectAtIndex:i] longLongValue];
    [_doneButton setTitle:[NSString stringWithFormat:@"DONE (%.2f MB)",fsize/1024.0/1024.0] forState:UIControlStateNormal];
    
    return cell;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [theData count];
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    int row = [indexPath row];
    NSString* filename = [theData objectAtIndex:row];
    NSLog(@"DID SELECT %@", filename);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    NSString* docString = [docDir stringByAppendingPathComponent:filename];
    NSURL* docURL = [NSURL fileURLWithPath:docString];
    UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:docURL];
    self->docCtrl = docController;
    [docController setDelegate:self];
    [docController presentPreviewAnimated:YES];
    
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE IT?"
                                                    message:@"Permanently delete the file?"
                                                   delegate:self
                                          cancelButtonTitle:@"HELL NO"
                                          otherButtonTitles:filename, nil];
    [alert show];
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller
{
    return self;
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* buttonStr = [alertView buttonTitleAtIndex:buttonIndex];
    if ([buttonStr compare:@"HELL NO"] == NSOrderedSame) {
        NSLog(@"NO DON'T DELETE FILE");
    } else {
        NSString* filename = [alertView buttonTitleAtIndex:buttonIndex];
        NSLog(@"YES I AM DELETING %@", filename);
        [docCtrl dismissPreviewAnimated:YES];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docDir = [paths objectAtIndex:0];
        NSString* docString = [docDir stringByAppendingPathComponent:filename];
        [[NSFileManager defaultManager] removeItemAtPath:docString error:Nil];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        theData = Nil;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
