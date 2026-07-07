#include <Foundation/Foundation.h>

#ifndef APP_ID
#define APP_ID @"fallback"
#endif
#ifndef CERT_ID
#define CERT_ID @"fallback"
#endif

#define kIsDebuggingResponce true

#define kBundlePath @"/Library/Application Support/dev.preloading.ebayx2"


NSString *URLEncode(NSString *string);
NSDate *FormatDate(NSString *input);
NSString *iso8601DurationMaker(NSDate *startDate, NSDate *endDate);
NSString *StripKeyValuePairs(NSString *input);