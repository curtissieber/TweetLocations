//
//  TWLocDetailViewController.m
//  
//
//  Created by Curtis Sieber on 1/26/14.
//
//

#import "TWLocDetailViewController.h"
#import "URLFetcher.h"

@implementation TWLocDetailViewController

+ (BOOL)imageExtension:(NSString*)urlStr
{
    NSRange checkRange = NSMakeRange([urlStr length]-5, 5);
    if ([urlStr compare:@".jpeg" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    checkRange = NSMakeRange([urlStr length]-4, 4);
    if ([urlStr compare:@".jpg" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".jpg:large" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".png" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr compare:@".gif" options:NSCaseInsensitiveSearch range:checkRange] == NSOrderedSame)
        return YES;
    if ([urlStr rangeOfString:@".jpg?"].location != NSNotFound)
        return YES;
    if ([TWLocDetailViewController isVideoFileURL:urlStr])
        return YES;
    //NSLog(@"No");
    return NO;
}

+ (BOOL)isVideoFileURL:(NSString*)url
{
    if ([url rangeOfString:@"tumblr.com/video_file/"].location != NSNotFound)
        return YES;
    if ([url rangeOfString:@".mp4?"].location != NSNotFound)
        return YES;
    NSRange range = [url rangeOfString:@".mp4"];
    if (range.location == NSNotFound)
        return NO;
    for (int i=range.location+range.length; i < [url length]; i++) {
        char c = [url characterAtIndex:i];
        if (isalnum(c))
            return NO;
    }
    return YES;
}

+ (NSMutableArray*)staticGetURLs:(NSString*)html
{
    NSMutableArray* strResults = [[NSMutableArray alloc] initWithCapacity:10];
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:Nil];
    [detector enumerateMatchesInString:html options:0 range:NSMakeRange(0, [html length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if ([result resultType] == NSTextCheckingTypeLink) {
            NSString* urlStr = [[result URL] absoluteString];
            if ([urlStr characterAtIndex:[urlStr length]-1] == '\'' &&
                [urlStr length] > 3)
                urlStr = [urlStr substringToIndex:[urlStr length]-2];
            if ([urlStr compare:@"tel:" options:0 range:NSMakeRange(0, 4)] != NSOrderedSame) {
                if ([urlStr rangeOfString:@"%5C"].location != NSNotFound) {
                    NSRange range = [urlStr rangeOfString:@"%5C"];
                    urlStr = [urlStr substringToIndex:range.location];
                }
                if ([urlStr rangeOfString:@"http"].location != 0) {
                    NSRange range = [urlStr rangeOfString:@"http"];
                    if (range.location != NSNotFound)
                        urlStr = [urlStr substringFromIndex:range.location];
                }
                [strResults addObject:urlStr];
                *stop = ([strResults count] > 100);
            }
        }
    }];
    return strResults;
}

+ (NSArray*)sorts {
    static NSArray* jpgSorted = Nil;
    if (jpgSorted == Nil)
        jpgSorted = [[NSArray alloc] initWithObjects:
                     @"/instagr.am/", @"instagram.com/",
                     @".mp4",
                     @".jpg?",
                     @"pinterest.com/original",
                     @"pinterest.com/736",
                     @"pinterest.com/550",
                     @"pinterest.com/500",
                     @"pinimg.com/original",
                     @"pinimg.com/736",
                     @"pinimg.com/550",
                     @"pinimg.com/500",
                     @".tumblr.com/image/",
                     @"assets.tumblr.com/images/",
                     @".tumblr.com/previews/",
                     @"tumblr.co/",
                     @"media.tumblr.com/",
                     @"tumblr.com/video_file/",
                     nil];
    return jpgSorted;
}

+ (NSString*)staticFindJPG:(NSMutableString*)html theUrlStr:(NSString*)url
{
    NSMutableArray* htmlResults = [self staticGetURLs:html];
    NSEnumerator* e = [htmlResults objectEnumerator];
    NSString* current;
    NSMutableArray* strResults = [[NSMutableArray alloc] initWithCapacity:10];
    
    while ((current = [e nextObject]) != Nil) {
        if ([TWLocDetailViewController imageExtension:current])
            [strResults addObject:current];
        else if ([[TWLocDetailViewController sorts] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            NSString* string = obj;
            if ([string compare:current] == NSOrderedSame)
                return (*stop = YES);
            return NO;
        }] != NSNotFound)
            [strResults addObject:current];
    }
    
    [strResults sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSMutableString* str1 = [[NSMutableString alloc] initWithString:obj1];
        NSMutableString* str2 = [[NSMutableString alloc] initWithString:obj2];
        NSInteger istr1 = [[TWLocDetailViewController sorts] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            NSString* string = obj;
            if ([string compare:str1] == NSOrderedSame)
                return (*stop = YES);
            return NO;
        }];
        NSInteger istr2 = [[TWLocDetailViewController sorts] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            NSString* string = obj;
            if ([string compare:str2] == NSOrderedSame)
                return (*stop = YES);
            return NO;
        }];
        if ([str1 rangeOfString:@"tumblr"].location == NSNotFound ||
            [str2 rangeOfString:@"tumblr"].location == NSNotFound) {
            if (istr1 < istr2) return NSOrderedDescending;
            else if (istr1 > istr2) return NSOrderedAscending;
            else return NSOrderedSame;
        }
        
        // from here on , it's tumblr versus tumblr
        [str1 deleteCharactersInRange:NSMakeRange([str1 length]-4,4)];
        [str2 deleteCharactersInRange:NSMakeRange([str2 length]-4,4)];
        
        NSRange dropChars = NSMakeRange(0,[str1 length]);
        while (isdigit([str1 characterAtIndex:(dropChars.location+dropChars.length-1)]))
            dropChars.length--;
        [str1 deleteCharactersInRange:dropChars];
        dropChars = NSMakeRange(0,[str2 length]);
        while (isdigit([str2 characterAtIndex:(dropChars.location+dropChars.length-1)]))
            dropChars.length--;
        [str2 deleteCharactersInRange:dropChars];
        
        if ([str1 length] == 0 && [str2 length] > 0)
            return NSOrderedDescending; //NSOrderedAscending; but reverse it
        if ([str2 length] == 0 && [str1 length] > 0)
            return NSOrderedAscending; //NSOrderedDescending; but reverse it
        if ([str1 length] == 0 && [str2 length] == 0)
            return NSOrderedSame;
        
        if ([str1 integerValue] > [str2 integerValue])
            return NSOrderedAscending; //NSOrderedDescending; but reverse it
        if ([str1 integerValue] < [str2 integerValue])
            return NSOrderedDescending; //NSOrderedAscending; but reverse it
        
        return NSOrderedSame;
    }];
    
    NSString* str;
    NSString* replaceStr = Nil;
    if ([strResults count] > 0)
        replaceStr = [URLFetcher canReplaceURL:url array:strResults];
    else
        replaceStr = [URLFetcher canReplaceURL:url array:htmlResults];
    
    NSMutableString* allMatches = [[NSMutableString alloc] initWithCapacity:256];
    
    if ([strResults count] > 0) {
        e = [strResults objectEnumerator];
        while ((str = [e nextObject]) != Nil) {
            [allMatches appendString:str];
            [allMatches appendString:@"\n"];
            [allMatches appendString:@"\n"];
        }
    } else {
        [allMatches appendString:@"FULL URL LISTING\n\n"];
        e = [htmlResults objectEnumerator];
        while ((str = [e nextObject]) != Nil) {
            [allMatches appendString:str];
            [allMatches appendString:@"\n"];
            [allMatches appendString:@"\n"];
        }
    }
    
    [html setString:allMatches];
    if (replaceStr != Nil) {
        return replaceStr;
    }
    return Nil;
}

- (BOOL)openURL:(NSURL *)url {
    NSLog(@"NEED TO OVERRIDE openURL!!! in %@",[self class]);
    return NO;
}

- (void)doMainBlock:(mainBlockToDo)block
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        block();
    }];
}

@end
