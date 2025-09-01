#import <Foundation/Foundation.h>

@interface NewOAuthManager : NSObject

+(instancetype)sharedManager;
-(NSString *)currentToken;
- (void)refreshTokenInBackground;

@end