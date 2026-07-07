#include <Foundation/Foundation.h>
#import <execinfo.h>
#import "ebayheaders/EBayConnector.h"
#import "ebayheaders/FSFindItemsAdvancedRequest.h"
#import "ebayheaders/FSFindItemsAdvancedResponse.h"
#import "ebayheaders/Settings.h"
#import "ebayheaders/EBayItem.h"
#import "sbjson/JSON.h"
#import "NewOAuthManager.h"
#import "utils.h"

// %hook NSURL
// // + (instancetype)URLWithString:(NSString *)URLString {
// // 	void *callstack[128];
// // 	int frames = backtrace(callstack, 128);
// // 	char **symbols = backtrace_symbols(callstack, frames);
// // 	NSMutableString *callstackString = [NSMutableString stringWithFormat:@"[EbayX] Callstack for %@:\n", URLString];
// // 	for (int i = 0; i < frames; i++) {
// // 		[callstackString appendFormat:@"%s\n", symbols[i]];
// // 	}
// // 	NSLog(@"%@", callstackString);
	
// // 	free(symbols);
// // 	return %orig;
// // }

// + (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)responsep error:(NSError **)errorp {
// 	NSLog(@"[EbayX] Synchronus Request Sent! Yayayayay!");
// 	return %orig;
// }

// %end


// -[FSFindItemsAdvancedRequest apiURL]

%hook Settings
-(id)shoppingAPI {
	return @"https://open.api.ebay.com/shopping";
}
%end


// Aug 25 16:10:31 Logans-iPhone eBay[20339]: [EbayX] Callstack for http://svcs.ebay.com/services/search/FindingService/v1:
// 	0   EBayX.dylib                         0x003b5ddb _logos_meta_method$_ungrouped$NSURL$URLWithString$ + 72
// 	1   eBay                                0x0004b3df -[FSFindItemsAdvancedRequest apiURL] + 38
// 	2   eBay                                0x0003394d -[EBayConnector setupRequest] + 44
// 	3   eBay                                0x00033503 -[EBayConnector sendRequestReturningData] + 46
// 	4   eBay                                0x00032c3d -[EBayConnector sendRequest] + 308
// 	5   Foundation                          0x33c62e85 <redacted> + 972
// 	6   libsystem_c.dylib                   0x3b4cb311 <redacted> + 308
// 	7   libsystem_c.dylib                   0x3b4cb1d8 thread_start + 8


%hook EBayConnector

- (NSURLRequest *)setupRequest  {
	// void *callstack[128];
	// int frames = backtrace(callstack, 128);
	// char **symbols = backtrace_symbols(callstack, frames);
	// NSMutableString *callstackString = [@"[EbayX] Callstack for xml builder:\n" mutableCopy];
	// for (int i = 0; i < frames; i++) {
	// 	[callstackString appendFormat:@"%s\n", symbols[i]];
	// }
	// NSLog(@"%@", callstackString);
	
	// free(symbols);

	int apiType = [self.request apiType];
	if (apiType < 100) {
		return %orig;
	}


	id settings = [NSClassFromString(@"Settings") performSelector:@selector(sharedSettings)]; // it wont import
// NSLog(@"[DEBUG] target: %@, action: %@", self.target, NSStringFromSelector(self.action));
	// NSLog(@"[DEBUG] Responce Class: %@", [self.request responseClass]);

	// NSLog(@"[EbayX] setup da request: %@", [[self.request apiURL] class]);
	// return %orig;
	// if ([[self.request apiURL] isEqualToString:@"http://svcs.ebay.com/services/search/FindingService/v1"]) { // Finding service
	// 	// NSLog(@"[EbayX] We get to replace this request! EbayAPIThingy: %d", [self.request apiType]);

	// 	// From here we get free rain on what to send, and how to process it (probably i hope). 
	// 	// I don't think the responce is processed as XML, which is good for us, since the new responce is JSON.
	// 	// New API URL is https://api.ebay.com/buy/browse/v1/item_summary/search, which is JSON.
	// 	// See https://developer.ebay.com/api-docs/buy/browse/resources/item_summary/methods/search for docs on this request.
	// } else {
	// 	return %orig;
	// }

	
	// Get the API URL from the request
    NSString *apiURL = [self.request apiURL];
    
    // Create mutable URL request
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiURL]
                                                            cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                        timeoutInterval:60.0];
        
    // if ([self.request siteIDOverride] != nil) {
    //     siteID = [[self.request siteIDOverride] stringValue];
    // } else {
    //     siteID = [[settings siteID] stringValue];
    // }
	
	if (apiType == 101) {
		[urlRequest setHTTPMethod:@"GET"];

		[urlRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	}
	
	NSString *countryCode;
	if ([[NSClassFromString(@"SignInController") performSelector:@selector(sharedController)] signedIn] && [settings myLocationCountryIsGoodForSearch]) {
		countryCode = [settings myLocationCountry];
	} else {
		countryCode = [[settings currentSite] isoCode];
	}

	if (![self.request postalCode]) {
		[self.request setPostalCode:[settings myLocationPostalCodeTrimmedForSearch]];
	}
	if ([self.request postalCode]) {
		[urlRequest addValue:[NSString stringWithFormat:@"contextualLocation=%@", URLEncode([NSString stringWithFormat:@"country=%@,zip=%@", countryCode, [self.request postalCode]])] forHTTPHeaderField:@"X-EBAY-C-ENDUSERCTX"];
	}
	

	[urlRequest addValue:[settings appID] forHTTPHeaderField:@"X-EBAY-SOA-SECURITY-APPNAME"];
	[urlRequest addValue:[[settings currentSite] globalID] forHTTPHeaderField:@"X-EBAY-C-MARKETPLACE-ID"];
	[urlRequest addValue:[NSString stringWithFormat:@"Bearer %@", [[NewOAuthManager sharedManager] currentToken]] forHTTPHeaderField:@"Authorization"];
	
	// [urlRequest addValue:[self.request verb] forHTTPHeaderField:@"X-EBAY-SOA-OPERATION-NAME"];

	return urlRequest;
}

// -(BOOL)shouldLogXML {
// 	return true;
// }

%end


%ctor {
	[[NewOAuthManager sharedManager] refreshTokenInBackground];
}