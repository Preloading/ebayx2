#include <Foundation/Foundation.h>
#import <execinfo.h>
#import "ebayheaders/EBayConnector.h"
#import "ebayheaders/FSFindItemsAdvancedRequest.h"
#import <curl/curl.h>

NSString *URLEncode(NSString *string) {
    return (__bridge_transfer NSString *)
        CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (__bridge CFStringRef)string,
            NULL,
            CFSTR("!*'();:@&=+$,/?%#[]"),
            kCFStringEncodingUTF8);
}


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

%hook FSFindItemsAdvancedRequest

-(id)apiURL {
	id settings = [NSClassFromString(@"Settings") performSelector:@selector(sharedSettings)]; // i don wanna import dis class ok?

	NSString *u = [NSString stringWithFormat:@"https://api.ebay.com/buy/browse/v1/item_summary/search?"];

	if (self.pageNumber > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"limit=%d&offset=%d&", self.maxEntries, self.pageNumber]];
	}

	if ([self.itemSort isEqualToString:@"Distance"]) {
       u=[u stringByAppendingString:@"sort=distance&"];
    } else if ([self.itemSort isEqualToString:@"PricePlusShippingLowest"]) {
       u=[u stringByAppendingString:@"sort=price&"];
    } else if ([self.itemSort isEqualToString:@"PricePlusShippingHighest"]) {
       u=[u stringByAppendingString:@"sort=-price&"];
    } else if ([self.itemSort isEqualToString:@"EndTimeSoonest"]) {
       u=[u stringByAppendingString:@"sort=endingSoonest&"];
    } else if ([self.itemSort isEqualToString:@"StartTimeNewest"]) {
       u=[u stringByAppendingString:@"sort=newlyListed&"];
    }

	// this doesn't look ever used?
	[self validateItemTypes];
	// NSMutableArray *itemTypeArray = [self valueForKey:@"itemTypeArray"];
	// if (itemTypeArray && itemTypeArray.count > 0) {
	// 	for (int i = 0; i > itemTypeArray.count; i++) {
	// 		NSLog(@"[EbayX] Item Type Array: %@", itemTypeArray[i]);
	// 	}
    // }

	NSMutableArray *aspectFilter = [[NSMutableArray alloc] init];

	NSMutableArray *filters = [[NSMutableArray alloc] init];
	if (self.searchDescriptions) {
		[filters addObject:@"searchInDescription:true"];
	}

	NSLog(@"[EBayX] category id is class of %@", [self.categoryID class]);
	if (self.categoryID && [self.categoryID length] > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"category_ids=%@&", self.categoryID]];
		[aspectFilter addObject:[NSString stringWithFormat:@"categoryId:%@", self.categoryID]];
	}

	// Histograms
	NSMutableArray *histograms = [[NSMutableArray alloc] init];
	if (self.includeAspectHistogram) {
		[histograms addObject:@"ASPECT_REFINEMENTS"];
	}
	
	if (self.includeCategoryHistogram) {
		[histograms addObject:@"CATEGORY_REFINEMENTS"];
	}

	if ([histograms count] > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"fieldgroups=%@&", [histograms componentsJoinedByString:@","]]];
	}

	// i'm debating whether to add local shipping
	if (self.priceMin && self.priceMax && ![[self.priceMax rawDecimalAsString] isEqual:@-1]) {
		[filters addObject:[NSString stringWithFormat:@"price:[%@..%@]", [self.priceMin rawDecimalAsString], [self.priceMax rawDecimalAsString]]];
		[filters addObject:[NSString stringWithFormat:@"priceCurrency:%@", [self.priceMin currencyID]]];
	} else if (self.priceMin) {
		[filters addObject:[NSString stringWithFormat:@"price:[%@]", [self.priceMin rawDecimalAsString]]];
		[filters addObject:[NSString stringWithFormat:@"priceCurrency:%@", [self.priceMin currencyID]]];
	} else if (self.priceMax && ![[self.priceMax rawDecimalAsString] isEqual:@-1]) {
		[filters addObject:[NSString stringWithFormat:@"price:[..%@]", [self.priceMax rawDecimalAsString]]];
		[filters addObject:[NSString stringWithFormat:@"priceCurrency:%@", [self.priceMax currencyID]]];
	}

	if (self.sellerID && [self.sellerID length] > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"seller={%@}&", self.sellerID]]; // TODO: Escape this
    }

	// Country search

	NSString *countryCode = nil;

	id signInController = [NSClassFromString(@"SignInController") performSelector:@selector(sharedController)];

	BOOL signedIn = NO;
	if ([signInController respondsToSelector:@selector(signedIn)]) {
		signedIn = ((BOOL (*)(id, SEL))[signInController methodForSelector:@selector(signedIn)])(signInController, @selector(signedIn));
	}

	BOOL myLocationGood = NO;
	if ([settings respondsToSelector:@selector(myLocationCountryIsGoodForSearch)]) {
		myLocationGood = ((BOOL (*)(id, SEL))[settings methodForSelector:@selector(myLocationCountryIsGoodForSearch)])(settings, @selector(myLocationCountryIsGoodForSearch));
	}

	if (signedIn && myLocationGood) {
		if ([settings respondsToSelector:@selector(myLocationCountry)]) {
			countryCode = [settings performSelector:@selector(myLocationCountry)];
		}
	} else {
		id currentSite = nil;
		if ([settings respondsToSelector:@selector(currentSite)]) {
			currentSite = [settings performSelector:@selector(currentSite)];
		}
		if ([currentSite respondsToSelector:@selector(isoCode)]) {
			countryCode = [currentSite performSelector:@selector(isoCode)];
		}
	}

	// requires results to be at least shipable to your country.
	if (countryCode) {
		[filters addObject:[NSString stringWithFormat:@"deliveryCountry:%@", countryCode]];
	}
	
	if (!self.searchOtherCountries) {
		[filters addObject:[NSString stringWithFormat:@"itemLocationCountry:%@", countryCode]];
	}

	if (self.minBids && self.maxBids && self.maxBids != -1) {
		[filters addObject:[NSString stringWithFormat:@"bidCount:[%d..%d]", self.minBids, self.maxBids]];
	} else if (self.minBids) {
		[filters addObject:[NSString stringWithFormat:@"bidCount:[%d]", self.minBids]];
	} else if (self.maxBids && self.maxBids != -1) {
		[filters addObject:[NSString stringWithFormat:@"bidCount:[..%d]", self.maxBids]];
	}

	if ([self.itemCondition isEqualToString:@"Unspecified"]) {
		[filters addObject:@"conditions:{UNSPECIFIED}"];
	} else if ([self.itemCondition isEqualToString:@"New"]) {
		[filters addObject:@"conditions:{NEW}"];
	} else if ([self.itemCondition isEqualToString:@"Used"]) {
		[filters addObject:@"conditions:{USED}"];
	}

	 // Aspect filters
	NSArray *aspectFilterArray = [self valueForKey:@"aspectFilterArray"];
    if (aspectFilterArray && aspectFilterArray.count > 0) {
        for (NSDictionary *aspectFilter1 in aspectFilterArray) {
			[aspectFilter addObject:[NSString stringWithFormat:@"%@:{%@}", aspectFilter1[@"name"], [aspectFilter1[@"values"] componentsJoinedByString:@"|"]]];
        }	
		u=[u stringByAppendingString:[NSString stringWithFormat:@"aspect_filter=%@&", [aspectFilter componentsJoinedByString:@","]]];
    }

	if (filters && filters.count > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"filters=%@&", URLEncode([filters componentsJoinedByString:@","])]];
	}

	u=[u stringByAppendingString:[NSString stringWithFormat:@"q=%@&", URLEncode(self.query) ]];

	// GET https://api.ebay.com/buy/browse/v1/item_summary/search?
	// q=string&
	// gtin=string&
	// charity_ids=string&
	// fieldgroups=string&
	// compatibility_filter=CompatibilityFilter&
	// auto_correct=string&
	// category_ids=string&
	// filter=FilterField&
	// sort=SortField&
	// limit=string&
	// offset=string&
	// aspect_filter=AspectFilter&
	// epid=string&
	NSLog(@"[EBayX] URLS are: %@", u);
	return [NSURL URLWithString:u];
}

// Aug 25 16:31:40 Logans-iPhone eBay[20512]: [EbayX] Callstack for xml builder:
// 	0   EBayX.dylib                         0x003b5db5 _logos_method$_ungrouped$FSFindItemsAdvancedRequest$buildRequest + 50
// 	1   eBay                                0x00006ef5 -[APIRequest data] + 24
// 	2   eBay                                0x000339c7 -[EBayConnector setupRequest] + 166
// 	3   eBay                                0x00033503 -[EBayConnector sendRequestReturningData] + 46
// 	4   eBay                                0x00032c3d -[EBayConnector sendRequest] + 308
// 	5   Foundation                          0x33c62e85 <redacted> + 972
// 	6   libsystem_c.dylib                   0x3b4cb311 <redacted> + 308
// 	7   libsystem_c.dylib                   0x3b4cb1d8 thread_start + 8


-(void)buildRequest {
	void *callstack[128];
	int frames = backtrace(callstack, 128);
	char **symbols = backtrace_symbols(callstack, frames);
	NSMutableString *callstackString = [@"[EbayX] Callstack for xml builder:\n" mutableCopy];
	for (int i = 0; i < frames; i++) {
		[callstackString appendFormat:@"%s\n", symbols[i]];
	}
	NSLog(@"%@", callstackString);
	
	free(symbols);
	return %orig;
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
	NSLog(@"[EbayX] setup da request: %@", [[self.request apiURL] class]);
	// if ([[self.request apiURL] isEqualToString:@"http://svcs.ebay.com/services/search/FindingService/v1"]) { // Finding service
	// 	// NSLog(@"[EbayX] We get to replace this request! EbayAPIThingy: %d", [self.request apiType]);

	// 	// From here we get free rain on what to send, and how to process it (probably i hope). 
	// 	// I don't think the responce is processed as XML, which is good for us, since the new responce is JSON.
	// 	// New API URL is https://api.ebay.com/buy/browse/v1/item_summary/search, which is JSON.
	// 	// See https://developer.ebay.com/api-docs/buy/browse/resources/item_summary/methods/search for docs on this request.
	// } else {
	// 	return %orig;
	// }
	return %orig;
}

%end

%hook Settings

- (id)appID {
	return @"JohnFort-echobayf-PRD-266f79d08-ec4532d2"; // New API APPID, temp from special head
}

%end

// haha, turns out ebay only support TLSv1.0. And it uses a **custom** http sender. thats fun. I don't like it, so lets replace it with curl. AI sadly, i dont get C :(
%hook URLConnectionCF

// curl write callback
static size_t writeCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    NSMutableData *data = (__bridge NSMutableData *)userp;
    [data appendBytes:contents length:size * nmemb];
    return size * nmemb;
}

// curl header callback
static size_t headerCallback(char *buffer, size_t size, size_t nitems, void *userdata) {
    NSMutableDictionary *headers = (__bridge NSMutableDictionary *)userdata;
    NSString *line = [[NSString alloc] initWithBytes:buffer
                                              length:size * nitems
                                            encoding:NSUTF8StringEncoding];
    NSRange sep = [line rangeOfString:@":"];
    if (sep.location != NSNotFound) {
        NSString *key = [[line substringToIndex:sep.location]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *val = [[line substringFromIndex:sep.location + 1]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key.length > 0 && val.length > 0) {
            headers[key] = val;
        }
    }
    return size * nitems;
}

- (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(NSURLResponse **)response
                             error:(NSError **)error
{
    CURL *curl = curl_easy_init();
    if (!curl) {
        if (error) {
            *error = [NSError errorWithDomain:@"URLConnectionCF"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey : @"Failed to init curl"}];
        }
        return nil;
    }

    NSMutableData *responseData = [NSMutableData data];
    NSMutableDictionary *responseHeaders = [NSMutableDictionary dictionary];

	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L); // TODO: make it actually secure lmao. Currently we get error 60, SSL error, but it does pass if we don't verify soo yeah.

    // URL
    curl_easy_setopt(curl, CURLOPT_URL, [[request.URL absoluteString] UTF8String]);

    // Timeout
    NSTimeInterval timeout = [request timeoutInterval];
    if (timeout > 0) {
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, (long)timeout);
    }

    // Method + body
    NSString *method = [request HTTPMethod] ?: @"GET";
    if ([method isEqualToString:@"POST"]) {
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        NSData *body = [request HTTPBody];
        if (body) {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [body bytes]);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, [body length]);
        }
    } else if (![method isEqualToString:@"GET"]) {
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, [method UTF8String]);
        NSData *body = [request HTTPBody];
        if (body) {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [body bytes]);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, [body length]);
        }
    }

    // Headers
    struct curl_slist *headers = NULL;
    for (NSString *key in [request allHTTPHeaderFields]) {
        NSString *line = [NSString stringWithFormat:@"%@: %@", key, request.allHTTPHeaderFields[key]];
        headers = curl_slist_append(headers, [line UTF8String]);
    }
    if (headers) {
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    }

    // Data + header callbacks
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (__bridge void *)responseData);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, headerCallback);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, (__bridge void *)responseHeaders);

    // Perform
    CURLcode res = curl_easy_perform(curl);
    long httpCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);

    curl_easy_cleanup(curl);
    if (headers) curl_slist_free_all(headers);

    if (res != CURLE_OK) {
        if (error) {
            *error = [NSError errorWithDomain:@"URLConnectionCF"
                                         code:res
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:curl_easy_strerror(res)]}];
			NSLog(@"[EbayX] an error has occured! o no! %@", [NSString stringWithUTF8String:curl_easy_strerror(res)]);
        }
        return nil;
    }

    // Build NSURLResponse
    if (response) {
        NSHTTPURLResponse *httpResp = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                  statusCode:httpCode
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:responseHeaders];
        *response = httpResp;
    }

	NSLog(@"[EbayX] req good!");
    return responseData;
}

%end