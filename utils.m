#import "utils.h"

NSString *URLEncode(NSString *string) {
    return (__bridge_transfer NSString *)
        CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (__bridge CFStringRef)string,
            NULL,
            CFSTR("!*'();:@&=+$,/?%#[]"),
            kCFStringEncodingUTF8);
}


NSDate *FormatDate(NSString *input) {
 NSDateFormatter *dateFormat = [NSDateFormatter new];
 //correcting format to include seconds and decimal place
 dateFormat.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
 // Always use this locale when parsing fixed format date strings
 NSLocale* posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
 dateFormat.locale = posix;
 return [dateFormat dateFromString:input];
}


// this was mostly AI. I really dont like dealing with time, so uhhhh yeah soz.
NSString *iso8601DurationMaker(NSDate *startDate, NSDate *endDate) {
    if (!endDate) {
        return @"P0DT0H0M0S";
    }

    NSDate *now = [NSDate date];
    if ([now compare:endDate] == NSOrderedDescending) {
        // If now is after endDate, item has ended
        return @"P0DT0H0M0S";
    }

    NSTimeInterval interval = [endDate timeIntervalSinceDate:now];
    if (interval <= 0) {
        return @"P0DT0H0M0S";
    }

    NSInteger totalSeconds = (NSInteger)interval;
    NSInteger days = totalSeconds / 86400;
    NSInteger hours = (totalSeconds % 86400) / 3600;
    NSInteger minutes = (totalSeconds % 3600) / 60;
    NSInteger seconds = totalSeconds % 60;

    return [NSString stringWithFormat:@"P%ldDT%ldH%ldM%ldS", (long)days, (long)hours, (long)minutes, (long)seconds];
}

NSString *StripKeyValuePairs(NSString *input) {
	// Split the input into words
	NSArray *words = [input componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSMutableArray *filteredWords = [NSMutableArray array];
	for (NSString *word in words) {
		NSRange colonRange = [word rangeOfString:@":"];
		if (colonRange.location == NSNotFound || colonRange.location == 0 || colonRange.location == word.length - 1) {
			// Keep words that do not look like key:value
			if ([word length] > 0) {
				[filteredWords addObject:word];
			}
		}
	}
	NSString *result = [filteredWords componentsJoinedByString:@" "];
	return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}