//
//  GoogleReader.m
//  TweetLocations
//
//  Created by Curtis Sieber on 11/2/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "GoogleReader.h"

@implementation GoogleReader

- (id)init
{
    self = [super init];
    _googleAccount = Nil;
    _googlePassword = Nil;
    _googleAuth = Nil;
    _googleToken = Nil;
    _googleTokenTime = 0;
    _googleUserInfo = Nil;
    return self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"CANCEL"]);
    //    return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _googleAccount = [[alertView textFieldAtIndex:0] text];
    _googlePassword = [[alertView textFieldAtIndex:1] text];
    NSLog(@"account=%@ passwd=%@",_googleAccount,_googlePassword);
    [defaults setObject:_googleAccount forKey:@"googleAccount"];
    [defaults setObject:_googlePassword forKey:@"googlePassword"];
    [defaults synchronize];
    
    [self tryAuthentication];
}

- (BOOL)authenticate:(BOOL)again
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _googleAccount = [defaults objectForKey:@"googleAccount"];
    _googlePassword = [defaults objectForKey:@"googlePassword"];

    if (again) {
        _googleAccount = Nil;
        _googlePassword = Nil;
        _googleAuth = Nil;
        _googleToken = Nil;
        _googleTokenTime = 0;
        _googleUserInfo = Nil;
    }
    if (_googleAuth != Nil)
        return YES;
    
    if (_googleAccount == Nil ||
        [_googleAccount length] < 2 ||
        _googlePassword == Nil ||
        [_googlePassword length] < 2) {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"GOOGLE Authentication Needed" message:@"Enter the account and password for your google account" delegate:self cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
        [alert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
        [alert show];
    }
    return YES;
}

- (BOOL)tryAuthentication
{
    if (_googleAccount == Nil ||
        [_googleAccount length] < 2)
        return NO;
    if (_googlePassword == Nil ||
        [_googlePassword length] < 2)
        return NO;
    
    return YES;
}
- (BOOL)isAuthenticated {return (_googleAuth != Nil); }

- (void)parseAuth:(NSString*)gotAuth
{
}

- (NSString*)myToken
{
    if (![self isAuthenticated]) return Nil;
    if (_googleToken != Nil &&
        (CACurrentMediaTime() - _googleTokenTime) < 4 * 60.0) // token expires 5 minutes
        return _googleToken;
    
    return _googleToken;
}

- (id)myUserInfo
{
    if (![self isAuthenticated]) return Nil;
    if (_googleUserInfo != Nil)
        return _googleUserInfo;
    
    return _googleUserInfo;
}

- (NSArray*)getStreams
{
    if (![self isAuthenticated]) return Nil;
    return Nil;
}

@end
