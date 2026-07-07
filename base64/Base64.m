//
//  Base64.m
//
//  Version 1.2
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (C) 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Base64
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an aacknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "Base64.h"


#pragma GCC diagnostic ignored "-Wselector"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This library requires automatic reference counting
#endif


@implementation NSData (Base64)

+ (NSData *)dataWithBase64EncodedString:(NSString *)string
{
    if (![string length]) return nil;
    
    NSData *decoded = nil;
    
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_10_9 || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    
    if (![NSData instancesRespondToSelector:@selector(initWithBase64EncodedString:options:)])
    {
        // Call legacy -initWithBase64Encoding: dynamically to avoid compile-time errors on newer SDKs
        SEL legacySel = NSSelectorFromString(@"initWithBase64Encoding:");
        if ([self instancesRespondToSelector:legacySel])
        {
            id instance = [self alloc];
            NSMethodSignature *sig = [self instanceMethodSignatureForSelector:legacySel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:legacySel];
            [inv setTarget:instance];
            NSString *clean = [string stringByReplacingOccurrencesOfString:@"[^A-Za-z0-9+/=]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [string length])];
            [inv setArgument:&clean atIndex:2];
            [inv invoke];
            __unsafe_unretained id result = nil;
            [inv getReturnValue:&result];
            decoded = result;
        }
        else
        {
            decoded = nil;
        }
    }
    else
    
#endif
        
    {
        // Call initWithBase64EncodedString:options: dynamically to avoid compile-time dependency on newer SDK constants
        SEL sel = NSSelectorFromString(@"initWithBase64EncodedString:options:");
        if ([self instancesRespondToSelector:sel])
        {
            id instance = [self alloc];
            NSMethodSignature *sig = [self instanceMethodSignatureForSelector:sel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:sel];
            [inv setTarget:instance];
            // argument 0 and 1 are self and _cmd, so user args start at index 2
            NSString *argString = string;
            NSUInteger options = 1; // NSDataBase64DecodingIgnoreUnknownCharacters == 1
            [inv setArgument:&argString atIndex:2];
            [inv setArgument:&options atIndex:3];
            [inv invoke];
            __unsafe_unretained id result = nil;
            [inv getReturnValue:&result];
            decoded = result;
        }
        else
        {
            // fallback if selector not available at runtime: call legacy init dynamically if present
            SEL legacySel = NSSelectorFromString(@"initWithBase64Encoding:");
            if ([self instancesRespondToSelector:legacySel])
            {
                id instance = [self alloc];
                NSMethodSignature *sig = [self instanceMethodSignatureForSelector:legacySel];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setSelector:legacySel];
                [inv setTarget:instance];
                NSString *clean = [string stringByReplacingOccurrencesOfString:@"[^A-Za-z0-9+/=]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [string length])];
                [inv setArgument:&clean atIndex:2];
                [inv invoke];
                __unsafe_unretained id result = nil;
                [inv getReturnValue:&result];
                decoded = result;
            }
            else
            {
                decoded = nil;
            }
        }
    }
    
    return [decoded length]? decoded: nil;
}

- (NSString *)base64EncodedStringWithWrapWidth:(NSUInteger)wrapWidth
{
    if (![self length]) return nil;
    
    NSString *encoded = nil;
    
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_10_9 || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    
    if (![NSData instancesRespondToSelector:@selector(base64EncodedStringWithOptions:)])
    {
        // Call legacy -base64Encoding dynamically to avoid compile-time errors on newer SDKs
        SEL legacySel = NSSelectorFromString(@"base64Encoding");
        if ([self respondsToSelector:legacySel])
        {
            NSMethodSignature *sig = [self methodSignatureForSelector:legacySel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:legacySel];
            [inv setTarget:self];
            [inv invoke];
            __unsafe_unretained NSString *result = nil;
            [inv getReturnValue:&result];
            encoded = result;
        }
        else
        {
            encoded = nil;
        }
    }
    else
    
#endif
    
    {
        // Call base64EncodedStringWithOptions: dynamically to avoid compile-time dependency on newer SDK constants
        SEL sel = NSSelectorFromString(@"base64EncodedStringWithOptions:");
        if ([self respondsToSelector:sel])
        {
            NSMethodSignature *sig = [self methodSignatureForSelector:sel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:sel];
            [inv setTarget:self];
            NSUInteger options = 0;
            if (wrapWidth == 64) options = 1; // NSDataBase64Encoding64CharacterLineLength == 1
            else if (wrapWidth == 76) options = 2; // NSDataBase64Encoding76CharacterLineLength == 2
            [inv setArgument:&options atIndex:2];
            [inv invoke];
            __unsafe_unretained NSString *result = nil;
            [inv getReturnValue:&result];
            if (options != 0)
            {
                // If wrapWidth corresponds to an encoding option, return directly
                return result;
            }
            encoded = result;
        }
        else
        {
            // Call legacy -base64Encoding dynamically to avoid compile-time errors on newer SDKs
            SEL legacySel = NSSelectorFromString(@"base64Encoding");
            if ([self respondsToSelector:legacySel])
            {
                NSMethodSignature *sig = [self methodSignatureForSelector:legacySel];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setSelector:legacySel];
                [inv setTarget:self];
                [inv invoke];
                __unsafe_unretained NSString *result = nil;
                [inv getReturnValue:&result];
                encoded = result;
            }
            else
            {
                encoded = nil;
            }
        }
    }
    
    if (!wrapWidth || wrapWidth >= [encoded length])
    {
        return encoded;
    }
    
    wrapWidth = (wrapWidth / 4) * 4;
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < [encoded length]; i+= wrapWidth)
    {
        if (i + wrapWidth >= [encoded length])
        {
            [result appendString:[encoded substringFromIndex:i]];
            break;
        }
        [result appendString:[encoded substringWithRange:NSMakeRange(i, wrapWidth)]];
        [result appendString:@"\r\n"];
    }
    
    return result;
}

- (NSString *)base64EncodedString
{
    return [self base64EncodedStringWithWrapWidth:0];
}

@end


@implementation NSString (Base64)

+ (NSString *)stringWithBase64EncodedString:(NSString *)string
{
    NSData *data = [NSData dataWithBase64EncodedString:string];
    if (data)
    {
        return [[self alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSString *)base64EncodedStringWithWrapWidth:(NSUInteger)wrapWidth
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    return [data base64EncodedStringWithWrapWidth:wrapWidth];
}

- (NSString *)base64EncodedString
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    return [data base64EncodedString];
}

- (NSString *)base64DecodedString
{
    return [NSString stringWithBase64EncodedString:self];
}

- (NSData *)base64DecodedData
{
    return [NSData dataWithBase64EncodedString:self];
}

@end
