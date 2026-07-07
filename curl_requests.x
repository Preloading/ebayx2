#import <curl/curl.h>
#import "utils.h"

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
	// 		void *callstack[128];
	// int frames = backtrace(callstack, 128);
	// char **symbols = backtrace_symbols(callstack, frames);
	// NSMutableString *callstackString = [@"[EbayX] Callstack for xml builder:\n" mutableCopy];
	// for (int i = 0; i < frames; i++) {
	// 	[callstackString appendFormat:@"%s\n", symbols[i]];
	// }
	// NSLog(@"%@", callstackString);
	
	// free(symbols);
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


	// SSL Shenanigans
    const char *caPath = [[NSString stringWithFormat:@"%@/cacert.pem", kBundlePath] UTF8String];
    curl_easy_setopt(curl, CURLOPT_CAINFO, caPath);
	// curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L); // potentially useful with a proxy

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

// 	NSLog(@"[EbayX] req good!");

	// NSLog(@"[DEBUG] curl url = %@", request.URL);
// 	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
// NSLog(@"[EbayX] HTTP Code %ld, Response Body:\n%@", httpCode, responseString);

    return responseData; 
}

%end