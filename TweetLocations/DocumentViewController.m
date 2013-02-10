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

static NSString* theFileNameToShare = Nil;
#define CANCELBUTTON @"HELL NO"
#define OPENINBUTTON @"Open In..."
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
    
    theFileNameToShare = filename;
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE IT?"
                                                    message:@"Permanently delete the file?"
                                                   delegate:self
                                          cancelButtonTitle:CANCELBUTTON
                                          otherButtonTitles:filename, OPENINBUTTON, nil];
    [alert show];
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller
{
    return self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* buttonStr = [alertView buttonTitleAtIndex:buttonIndex];
    if ([buttonStr compare:CANCELBUTTON] == NSOrderedSame) {
        NSLog(@"NO DON'T DELETE FILE");
    } else if ([buttonStr compare:OPENINBUTTON] == NSOrderedSame) {
        NSLog(@"Found the OpenIn... button");
        [docCtrl dismissPreviewAnimated:YES];
        NSTimer* timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeInterval:3.0
                                                                              sinceDate:[NSDate date]]
                                                  interval:0.7
                                                    target:self
                                                  selector:@selector(openDocumentIn:)
                                                  userInfo:Nil
                                                   repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
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

-(void)openDocumentIn:(NSTimer*)theTimer
{
    /*NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    NSString* docString = [docDir stringByAppendingPathComponent:theFileNameToShare];
    NSLog(@"creating a document interaction controller with %@", docString);
    [UIDocumentInteractionController
     interactionControllerWithURL:[NSURL fileURLWithPath:docString]];
    docCtrl.delegate = self;*/
    docCtrl.UTI = @"com.apple.quicktime-movie";
    NSLog(@"presenting the open in ... menu");
    [docCtrl presentOpenInMenuFromRect:CGRectZero
                                           inView:_detailView.view
                                         animated:YES];
}

-(void)documentInteractionController:(UIDocumentInteractionController *)controller
       willBeginSendingToApplication:(NSString *)application {
    NSLog(@"began sending to app %@", application);
}

-(void)documentInteractionController:(UIDocumentInteractionController *)controller
          didEndSendingToApplication:(NSString *)application {
    NSLog(@"ended sending to app %@", application);
}

-(void)documentInteractionControllerDidDismissOpenInMenu:
(UIDocumentInteractionController *)controller {
    NSLog(@"CANCELLED the open in ... menu");
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
