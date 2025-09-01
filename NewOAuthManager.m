#import "NewOAuthManager.h"
#import "sbjson/JSON.h"
#import "base64/Base64.h"

#ifndef APP_ID
#define APP_ID @"fallback"
#endif
#ifndef CERT_ID
#define CERT_ID @"fallback"
#endif

@interface NewOAuthManager ()
@property (nonatomic, strong) NSString *token;
@property (nonatomic, assign) NSTimeInterval expiresAt;
@property (nonatomic, strong) NSOperationQueue *tokenOperationQueue;
@end

@implementation NewOAuthManager


+ (instancetype)sharedManager {
    static NewOAuthManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
        sharedManager.tokenOperationQueue = [[NSOperationQueue alloc] init];
        sharedManager.tokenOperationQueue.maxConcurrentOperationCount = 1;
        NSLog(@"[EbayX] NewOAuthManager singleton initialized: %p", sharedManager);
    });
    return sharedManager;
}

// used mostly by mapkit stuff
- (NSString *)currentToken {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if (_token && now + 300 < _expiresAt) {
        // Token is valid and not about to expire
        // Start async refresh if token will expire soon (within 15 minutes)
        if (now + 900 >= _expiresAt) {
            [self refreshTokenInBackground];
        }
        return _token;
    } else {
        // Token is nil or expired or about to expire - need synchronous refresh
        NSInteger expiresIn = 0;
        _token = [self requestNewToken:&expiresIn];
        
        if (_token) {
            _expiresAt = now + expiresIn;
        }
        return _token;
    }
}

- (void)getTokenWithCompletion:(void (^)(NSString *token))completion {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if (_token && now + 300 < _expiresAt) {
        // Token is valid, return immediately
        completion(_token);
        
        // Refresh in background if needed
        if (now + 900 >= _expiresAt) {
            [self refreshTokenInBackground];
        }
    } else {
        // Need to get a new token
        [self.tokenOperationQueue addOperationWithBlock:^{
            NSInteger expiresIn = 0;
            NSString *newToken = [self requestNewToken:&expiresIn];
            
            if (newToken) {
                self.token = newToken;
                self.expiresAt = [[NSDate date] timeIntervalSince1970] + expiresIn;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(newToken);
            });
        }];
    }
}

- (void)refreshTokenInBackground {
    [self.tokenOperationQueue addOperationWithBlock:^{
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        // Only refresh if we still need to (another operation might have refreshed already)
        if (!self.token || now + 300 >= self.expiresAt) {
            NSInteger expiresIn = 0;
            NSString *newToken = [self requestNewToken:&expiresIn];
            
            if (newToken) {
                self.token = newToken;
                self.expiresAt = [[NSDate date] timeIntervalSince1970] + expiresIn;
                NSLog(@"Token refreshed in background");
            }
        }
    }];
}

- (NSString *)requestNewToken:(NSInteger *)outExpiresIn {
    NSString *oauthURL = @"https://api.ebay.com/identity/v1/oauth2/token";
    NSURL *url = [NSURL URLWithString:oauthURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url 
                                     cachePolicy:NSURLRequestUseProtocolCachePolicy 
                                 timeoutInterval:60.0];

    NSString *encodedTokenData = [[NSString stringWithFormat:@"%@:%@",APP_ID,CERT_ID] base64EncodedStringWithWrapWidth:0];
    
    [request setHTTPMethod:@"POST"];
    [request addValue:[NSString stringWithFormat:@"Basic %@", encodedTokenData] forHTTPHeaderField:@"Authorization"];
    [request addValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded"] forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[@"grant_type=client_credentials&scope=https%3A%2F%2Fapi.ebay.com%2Foauth%2Fapi_scope" dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *responseData = [NSClassFromString(@"URLConnectionCF") sendSynchronousRequest:request
                                         returningResponse:&response 
                                                     error:&error];
    
    if (error) {
        NSLog(@"Connection failed: %@", [error localizedDescription]);
        return nil;
    }

    NSLog(@"[DEBUG] responce = %@", [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding]);
    
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSDictionary *results = [parser objectWithString:[[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding]];

    if (outExpiresIn) {
        *outExpiresIn = [results[@"expires_in"] integerValue];
    }
    NSLog(@"[DEBUG] access token = %@", results[@"access_token"]);
    return results[@"access_token"];
}

@end