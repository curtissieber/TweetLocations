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
    }
    if (_googleAuth != Nil)
        return YES;
    
    if (_googleAccount == Nil ||
        [_googleAccount length] < 2 ||
        _googlePassword == Nil ||
        [_googlePassword length] < 2) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"GOOGLE Authentication Needed" message:@"Enter the account and password for your google account" delegate:self cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
            [alert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
            [alert show];
        }];
    } else {
        return [self tryAuthentication];
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
    
    [self myToken];
    
    return (_googleAuth != Nil && _googleToken != Nil);
}
- (BOOL)isAuthenticated {return (_googleAuth != Nil); }

- (void)parseAuth:(NSString*)gotAuth
{
}

- (NSString*)myToken
{
    if (_googleToken != Nil &&
        (CACurrentMediaTime() - _googleTokenTime) < 4 * 60.0) // token expires 5 minutes
        return _googleToken;
    
    if (_cookies == Nil || [_cookies count] < 1 || _googleAuth == Nil) {
        
        NSString * urlstr = [NSString stringWithFormat:@"https://www.google.com/accounts/ClientLogin?service=reader&Email=%@&Passwd=%@&accountType=GOOGLE", [self googleAccount], [self googlePassword]];
        NSURL* url = [NSURL URLWithString:urlstr];
        
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
        
        NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
        NSError* error = [[NSError alloc] init];
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"google session data = %@", respStr);
        NSLog(@"google session response = %ld", (long)[response statusCode]);
        NSLog(@"google session error = %ld", (long)[error code]);
        if ([response statusCode] != 200)
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting session keys", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
                [alert show];
            }];
        
        _cookies = [[NSMutableArray alloc] initWithCapacity:1];
        NSArray* items = [respStr componentsSeparatedByString:@"\n"];
        for(NSString * c in items) {
            NSArray* parts  = [c componentsSeparatedByString:@"="];
            if([parts count] == 2) {
                NSString* cName  = [parts objectAtIndex:0];
                NSString* cValue = [parts objectAtIndex:1];
                
                NSMutableDictionary * cookieProperties = [[NSMutableDictionary alloc] init];
                [cookieProperties setValue:cName forKey:NSHTTPCookieName];
                [cookieProperties setValue:cValue forKey:NSHTTPCookieValue];
                [cookieProperties setValue:@"/" forKey:NSHTTPCookiePath];
                [cookieProperties setValue:@".google.com" forKey:NSHTTPCookieDomain];
                
                NSHTTPCookie * cookie = [[NSHTTPCookie alloc] initWithProperties:cookieProperties];
                
                [_cookies addObject:cookie];
                
                if ([cName isEqualToString:@"SID"])
                    _strSID = cValue;
                if ([cName isEqualToString:@"LSID"])
                    _strLSID = cValue;
                if ([cName isEqualToString:@"Auth"])
                    _strAuth = cValue;
            }
        }
        _googleAuth = _strAuth;
        _googleToken = Nil;
    }
    [self requestToken];
        
    if (![self isAuthenticated]) return Nil;
    
    return _googleToken;
}

- (NSString *)auth
{
    if (_cookies == Nil)
        return Nil;
    
    for(NSHTTPCookie * cookie in _cookies) {
        if([[cookie name] isEqualToString:@"Auth"]) {
            return [cookie value];
        }
    }
    return nil;
}

- (void)requestToken
{
    if (_googleToken != Nil &&
        (CACurrentMediaTime() - _googleTokenTime) < 4 * 60.0) // token expires 5 minutes
        return;

    if(_cookies != Nil &&
       [_cookies count] > 0 &&
       [self auth] != Nil) {
        NSString * urlstr = @"http://www.google.com/reader/api/0/token";
        
        NSURL* url = [NSURL URLWithString:urlstr];
        
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
        NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
        [request setAllHTTPHeaderFields:headers];
        [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
        
        NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
        NSError* error = [[NSError alloc] init];
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"google token data = %@", respStr);
        NSLog(@"google token response = %ld", (long)[response statusCode]);
        NSLog(@"google token error = %ld", (long)[error code]);
        if ([response statusCode] != 200)
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting session TOKEN", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
                [alert show];
            }];

        _googleToken = respStr;
        _googleTokenTime = CACurrentMediaTime();
    }
}

- (NSArray*)getStreams
{
    if(![self authenticate:NO])
        return Nil;

    NSString * urlstr = @"http://www.google.com/reader/api/0/subscription/list?output=json&client=scroll";
    NSURL* url = [NSURL URLWithString:urlstr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
    NSError* error = [[NSError alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    //NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"google subscription data = %@", respStr);
    //NSLog(@"google subscription response = %ld", (long)[response statusCode]);
    //NSLog(@"google subscription error = %ld", (long)[error code]);
    if ([response statusCode] != 200)
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting streams", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
            [alert show];
        }];
    
    NSMutableArray * feeds = [NSMutableArray array];
    if([response statusCode] == 200) {
        if(data) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonError];

            if (json) {
                feeds = [json objectForKey:@"subscriptions"];
            }
        }
    }
    
    return feeds;
}

- (NSArray *)unreadRSSFeeds
{
    if(![self authenticate:NO])
        return Nil;
    
    NSString * timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString * urlstr = [NSString stringWithFormat:@"http://www.google.com/reader/api/0/unread-count?allcomments=false&output=json&ck=%@&client=scroll", timestamp];
    NSURL* url = [NSURL URLWithString:urlstr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
    NSError* error = [[NSError alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"google unreadRSS data = %@", respStr);
    NSLog(@"google unreadRSS response = %ld", (long)[response statusCode]);
    NSLog(@"google unreadRSS error = %ld", (long)[error code]);
    if ([response statusCode] != 200)
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting unread RSS feeds", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
            [alert show];
        }];

    if([response statusCode] != 200) {
        // Handle when status code is not 200
        return [NSArray array];
    }
    
    NSArray * feeds;
    NSDictionary * json;
    
    NSError *jsonError;
    json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonError];
    
    feeds = [json objectForKey:@"unreadcounts"];
    
    NSMutableArray * filteredFeeds = [NSMutableArray array];
    for(NSDictionary * f in feeds) {
        if([[f objectForKey:@"id"] hasPrefix:@"feed/"]) {
            [filteredFeeds addObject:f];
        }
    }
    
    return filteredFeeds;
}

- (NSString*)userID
{
    static NSString* userID = Nil;
    if (userID != Nil)
        return userID;
    
    if(![self authenticate:NO])
        return Nil;
    
    NSString * timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString * urlstr = [NSString stringWithFormat:@"https://www.google.com/reader/api/0/user-info?&ck=%@&client=scroll", timestamp];
    NSURL* url = [NSURL URLWithString:urlstr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
    NSError* error = [[NSError alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"google userID data = %@", respStr);
    NSLog(@"google userID response = %ld", (long)[response statusCode]);
    NSLog(@"google userID error = %ld", (long)[error code]);
    if ([response statusCode] != 200)
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting user ID", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
            [alert show];
        }];
    
    if([response statusCode] != 200) {
        // Handle when status code is not 200
        return Nil;
    }
    userID = respStr;
    
    return userID;
}

- (NSArray*)unreadItems:(NSString*)theID
{
    if(![self authenticate:NO])
        return Nil;
    
    //NSLog(@"getting unread items for %@",theID);
    NSString * timestampBegin = [NSString stringWithFormat:@"%ld", (long)[[NSDate dateWithTimeIntervalSinceNow:-365*24*60*60] timeIntervalSince1970]];
    NSString * timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString* streamName = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes( NULL,	 (CFStringRef)theID,	 NULL,	 (CFStringRef)@"!’\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8));
    NSString* readExclude = [NSString stringWithFormat:@"user/-/state/com.google/read"];
    readExclude = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes( NULL,	 (CFStringRef)readExclude,	 NULL,	 (CFStringRef)@"!’\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8));
    
    NSString * urlstr = [NSString stringWithFormat:@"https://www.google.com/reader/api/0/stream/contents/%@?ot=%@&r=n&xt=%@&n=2000&ck=%@&client=scroll",streamName,timestampBegin,readExclude,timestamp];
    // https://www.google.com/reader/api/0/stream/contents/
    // feed%2Fhttp%3A%2F%2Fthetubemonster.tumblr.com%2Frss?ot=1329505807&r=n&
    // xt=user%2F-%2Fstate%2Fcom.google%2Fread&n=20&ck=1361041807&client=scroll
    NSURL* url = [NSURL URLWithString:urlstr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
    NSError* error = [[NSError alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    //NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"google unreadItems data = %@", respStr);
    //NSLog(@"google unreadItems response = %ld", (long)[response statusCode]);
    //NSLog(@"google unreadItems error = %ld", (long)[error code]);
    if ([response statusCode] != 200)
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld getting unread items in %@", (long)[response statusCode], theID] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
            [alert show];
        }];
    
    if([response statusCode] != 200) {
        // Handle when status code is not 200
        NSLog(@"google unreadItems error = %ld (in %@)", (long)[error code], theID);
        return [NSArray array];
    }
    
    NSArray * items;
    NSDictionary * json;
    
    NSError *jsonError;
    json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&jsonError];
    
    items = [json objectForKey:@"items"];
    
    return items;
}

- (void)setRead:(NSString*)theID stream:(NSString*)theStream
{
    if (theID == Nil || [theID length] < 2)
        return;
    if (theStream == Nil || [theStream length] < 2)
        return;
    /*
     protected $_urlBase          =  'https://www.google.com';
     protected $_urlApi           =  'https://www.google.com/reader/api/0';
     protected $_urlAuth          =  'https://www.google.com/accounts/ClientLogin';
     protected $_urlToken         =  'https://www.google.com/reader/api/0/token';
     protected $_urlUserInfo      =  'https://www.google.com/reader/api/0/user-info';
     protected $_urlTag           =  'https://www.google.com/reader/api/0/tag';
     protected $_urlSubscription  =  'https://www.google.com/reader/api/0/subscription';
     protected $_urlStream        =  'https://www.google.com/reader/api/0/stream';
     protected $_urlFriend        =  'https://www.google.com/reader/api/0/friend';
function set_article_read($id,$stream) {
        $url = $this->_urlApi . '/edit-tag?pos=0&client=' . $this->userAgent;
        $data = 'a=user/-/state/com.google/read&async=true&s='.$stream.'&i='.$id.'&T='.$this->token;
        return $this->post_url($url,$data);
*/
    if(![self authenticate:NO])
        return;
    [self requestToken];
    
    NSString * urlstr = [NSString stringWithFormat:@"https://www.google.com/reader/api/0/edit-tag?pos=0?client=scroll"];
    NSURL* url = [NSURL URLWithString:urlstr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSDictionary * headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    [request setAllHTTPHeaderFields:headers];
    [request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", [self auth]] forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];
    NSString* httpData = [NSString stringWithFormat:@"a=user/-/state/com.google/read&async=false&s=%@&i=%@&T=%@", theStream, theID, _googleToken];
    [request setHTTPBody:[httpData dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]init];
    NSError* error = [[NSError alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString* respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"google setRead URL = %@", url);
    NSLog(@"google setRead httpData = %@", httpData);
    NSLog(@"google setRead data = %@", respStr);
    NSLog(@"google setRead response = %ld", (long)[response statusCode]);
    NSLog(@"google setRead error = %ld", (long)[error code]);
    if ([response statusCode] != 200)
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[NSString stringWithFormat:@"Google Error %ld setting article to READ status", (long)[response statusCode]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles:nil];
            [alert show];
        }];
    
    if ([response statusCode] != 200) {
        // Handle when status code is not 200
        NSLog(@"google setRead error = %ld (in %@)\n%@", (long)[error code], theID, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }
}
@end
