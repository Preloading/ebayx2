#include <Foundation/Foundation.h>
#import "ebayheaders/EBayConnector.h"
#import "ebayheaders/FSFindItemsAdvancedRequest.h"
#import "ebayheaders/FSFindItemsAdvancedResponse.h"
#import "ebayheaders/Settings.h"
#import "ebayheaders/EBayItem.h"
#import "sbjson/JSON.h"
#import "utils.h"

%hook FSFindItemsAdvancedRequest

-(id)apiURL {
	id settings = [NSClassFromString(@"Settings") performSelector:@selector(sharedSettings)]; // i don wanna import dis class ok?

	NSString *u = [NSString stringWithFormat:@"https://api.ebay.com/buy/browse/v1/item_summary/search?"];

	if (self.pageNumber > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"limit=%d&offset=%d&", self.maxEntries, self.maxEntries*(self.pageNumber-1)]];
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

	

	NSMutableArray *aspectFilter = [[NSMutableArray alloc] init];

	NSMutableArray *filters = [[NSMutableArray alloc] init];
	if (self.searchDescriptions) {
		[filters addObject:@"searchInDescription:true"];
	}

	[self validateItemTypes];

	bool hasAlreadyDoneAuction = false;
	NSMutableArray *itemTypeArray = [self valueForKey:@"itemTypeArray"];
	NSMutableArray *buyingOptions = [[NSMutableArray alloc] init];
	if (itemTypeArray && itemTypeArray.count > 0) {
		for (int i = 0; i < itemTypeArray.count; i++) {
			// NSLog(@"[EbayX] it's %@ yayayayayayay", itemTypeArray[i]);
			if (([itemTypeArray[i] isEqualToString:@"Auction"] || [itemTypeArray[i] isEqualToString:@"AuctionWithBIN"]) && !hasAlreadyDoneAuction) {
				[buyingOptions addObject:@"AUCTION"];
				hasAlreadyDoneAuction = true;
			} else if ([itemTypeArray[i] isEqualToString:@"Classified"]) {
				[buyingOptions addObject:@"CLASSIFIED_AD"];
			} else if ([itemTypeArray[i] isEqualToString:@"FixedPrice"]) {
				[buyingOptions addObject:@"FIXED_PRICE"];
			}
		}
    }
	if ([buyingOptions count] > 0) {
		[filters addObject:[NSString stringWithFormat:@"buyingOptions:{%@}", [buyingOptions componentsJoinedByString:@"|"]]];
	}

	if (self.categoryID && [self.categoryID length] > 0) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"category_ids=%@&", self.categoryID]];
		[aspectFilter addObject:[NSString stringWithFormat:@"categoryId:%@", self.categoryID]];
	}

	// Histograms
	NSMutableArray *histograms = [[NSMutableArray alloc] init];
	[histograms addObject:@"MATCHING_ITEMS"];
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
		[filters addObject:[NSString stringWithFormat:@"sellers={%@}", self.sellerID]];
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
		u=[u stringByAppendingString:[NSString stringWithFormat:@"filter=%@&", URLEncode([filters componentsJoinedByString:@","])]];
	}

	NSString *query = StripKeyValuePairs(self.query); // removes seller:

	if (query) {
		u=[u stringByAppendingString:[NSString stringWithFormat:@"q=%@&", URLEncode(query) ]];
	}
	

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
	// NSLog(@"[EBayX] URLS are: %@", u);
	// return [NSURL URLWithString:u];
	return u;
}

-(int)apiType {
	return 101;
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
	return; // XML is not needed


	// void *callstack[128];
	// int frames = backtrace(callstack, 128);
	// char **symbols = backtrace_symbols(callstack, frames);
	// NSMutableString *callstackString = [@"[EbayX] Callstack for xml builder:\n" mutableCopy];
	// for (int i = 0; i < frames; i++) {
	// 	[callstackString appendFormat:@"%s\n", symbols[i]];
	// }
	// NSLog(@"%@", callstackString);
	
	// free(symbols);
	// return %orig;
}



%end


%hook FSFindItemsAdvancedResponse
- (void)parseData:(NSData *)data {
	SBJsonParser *parser = [[SBJsonParser alloc] init];

	// NSLog(@"[DEBUG] The data we have is %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
	NSDictionary *result = [parser objectWithString:[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]];

	if (result) {
		// yay!
		NSMutableArray *items = [[NSMutableArray alloc] init]; 
		NSArray *itemsJson = result[@"itemSummaries"];
		if (itemsJson) {
			NSLog(@"[EbayX] items: %lu", (unsigned long)[itemsJson count]);
			for (int i = 0; i < (unsigned long)[itemsJson count]; i++) {
				EBayItem *item = [[NSClassFromString(@"EBayItem") alloc] init];
				NSDictionary *jsonItem = itemsJson[i];

				// sellerInfo.feedbackRatingStar
				int score = [jsonItem[@"seller"][@"feedbackScore"] intValue];
				NSString *starRating;
				if (score >= 1000000) {
					starRating = @"SilverShooting";
				} else if (score >= 500000) {
					starRating = @"GreenShooting";
				} else if (score >= 100000) {
					starRating = @"RedShooting";
				} else if (score >= 50000) {
					starRating = @"PurpleShooting";
				} else if (score >= 25000) {
					starRating = @"TurquoiseShooting";
				} else if (score >= 10000) {
					starRating = @"YellowShooting";
				} else if (score >= 5000) {
					starRating = @"Green";
				} else if (score >= 1000) {
					starRating = @"Red";
				} else if (score >= 500) {
					starRating = @"Purple";
				} else if (score >= 100) {
					starRating = @"Turquoise";
				} else if (score >= 50) {
					starRating = @"Blue";
				} else if (score >= 10) {
					starRating = @"Yellow";
				} else {
					starRating = @"None";
				}


				// sellingStatus.convertedCurrentPrice
				NSDictionary *convertedCurrentPrice = nil;
				if (jsonItem[@"price"][@"convertedFromCurrency"]) {
					convertedCurrentPrice = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"convertedFromValue"] currencyID:jsonItem[@"price"][@"convertedFromCurrency"]];
				} else {
					convertedCurrentPrice = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"value"] currencyID:jsonItem[@"price"][@"currency"]];
				}

				// sellingStatus.timeLeft

				// listingInfo.buyItNowAvailable
				bool buyItNowAvailable = [jsonItem[@"buyingOptions"] containsObject:@"FIXED_PRICE"];
				
				// listingInfo.listingType
				NSString *listingType = @"Unknown";
				if ([jsonItem[@"buyingOptions"] containsObject:@"FIXED_PRICE"] && buyItNowAvailable) {
					listingType = @"AuctionWithBIN";
				} else if (buyItNowAvailable) {
					listingType = @"FixedPrice";
				} else if ([jsonItem[@"buyingOptions"] containsObject:@"AUCTION"]) {
					listingType = @"AuctionWithBIN";
				} else if ([jsonItem[@"buyingOptions"] containsObject:@"BEST_OFFER"]) {
					listingType = @"Auction"; // i guess?
				} else if ([jsonItem[@"buyingOptions"] containsObject:@"CLASSIFIED_AD"]) {
					listingType = @"Classified";
				}

				NSDate *creationTime = FormatDate(jsonItem[@"itemCreationDate"]);
				NSDate *currentTime = [NSDate date];
				NSCalendar *calendar = [NSCalendar currentCalendar];

				NSDate *startTime;
				NSDate *endTime;

				if (jsonItem[@"itemEndDate"]) {
					startTime = creationTime;
					endTime = FormatDate(jsonItem[@"itemEndDate"]);
				} else {
					// Calculate number of months between creation and now
					NSDateComponents *diff = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit
														fromDate:creationTime
														toDate:currentTime
														options:0];
					NSInteger months = diff.month + diff.year * 12;

					// Add that many months to creation
					NSDateComponents *addMonths = [[NSDateComponents alloc] init];
					addMonths.month = months;
					NSDate *candidate = [calendar dateByAddingComponents:addMonths toDate:creationTime options:0];

					// If candidate is after now, subtract one month
					if ([candidate compare:currentTime] == NSOrderedDescending) {
						addMonths.month = months - 1;
						candidate = [calendar dateByAddingComponents:addMonths toDate:creationTime options:0];
					}
					startTime = candidate;

					// End time is start time + 1 month - 10 seconds
					NSDateComponents *plusOneMonth = [[NSDateComponents alloc] init];
					plusOneMonth.month = 1;
					NSDate *oneMonthLater = [calendar dateByAddingComponents:plusOneMonth toDate:startTime options:0];
					endTime = [oneMonthLater dateByAddingTimeInterval:-10];
				}

				// sellingStatus.timeLeft
				NSString *timeLeft = @"P0DT0H0M0S";
				if ([[[NSDate date] laterDate:endTime] isEqualToDate:endTime]) { // i struggle with less than and greater than.
					// i hate time
					timeLeft = iso8601DurationMaker(startTime, endTime);
				}


				// listingInfo
				NSMutableDictionary *listingInfo = [@{
					@"buyItNowAvailable": @(buyItNowAvailable),
					@"bestOfferEnabled": @([jsonItem[@"buyingOptions"] containsObject:@"BEST_OFFER"]),
					@"listingType": listingType,
					@"startTime": startTime,
					@"endTime": endTime,
					@"gift": @NO

				} mutableCopy];

				if (buyItNowAvailable) {
					listingInfo[@"buyItNowPrice"] = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"value"] currencyID:jsonItem[@"price"][@"currency"]];

					if (jsonItem[@"price"][@"convertedFromCurrency"]) {
						listingInfo[@"convertedBuyItNowPrice"] = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"convertedFromValue"] currencyID:jsonItem[@"price"][@"convertedFromCurrency"]];
					} else {
						listingInfo[@"convertedBuyItNowPrice"] = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"value"] currencyID:jsonItem[@"price"][@"currency"]];
					}
				}
				// NSLog(@"[DEBUG] Currency ID is %@", [[[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"value"] currencyID:jsonItem[@"price"][@"currency"]] currencyID]);

				// combine everything into one mega dictionary.
				NSMutableDictionary *itemBase = [@{
					@"itemId": jsonItem[@"legacyItemId"],
					@"title": jsonItem[@"title"],
					@"primaryCategory": @{
						@"categoryId": jsonItem[@"categories"][0][@"categoryId"],
						@"categoryName": jsonItem[@"categories"][0][@"categoryName"],
					},
					@"viewItemURL": jsonItem[@"itemWebUrl"],
					@"autopay": @YES, // todo figure this out
					
					@"listingInfo": listingInfo,
					@"sellerInfo": @{
						@"feedbackScore": jsonItem[@"seller"][@"feedbackScore"],
						@"positiveFeedbackPercent": jsonItem[@"seller"][@"feedbackPercentage"],
						@"sellerUserName": jsonItem[@"seller"][@"username"],
						@"topRatedSeller": @NO, // this isn't publically accessible in the new api so ig no one is :D
						@"feedbackRatingStar": starRating,
					},

				} mutableCopy];
				if (jsonItem[@"image"][@"imageUrl"]) {
					itemBase[@"galleryURL"] = jsonItem[@"image"][@"imageUrl"];
				}

				NSMutableDictionary *sellingStatus = [@{
					
					@"currentPrice": [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"price"][@"value"] currencyID:jsonItem[@"price"][@"currency"]],
					@"convertedCurrentPrice": convertedCurrentPrice,
					@"sellingState": @"Active", // previous me said that this was a cheat. idk why.
					@"timeLeft": timeLeft,

				} mutableCopy];
				if (jsonItem[@"bidCount"]) {
					sellingStatus[@"bidCount"] = jsonItem[@"bidCount"];
				}
				itemBase[@"sellingStatus"] = sellingStatus;

				if (jsonItem[@"shippingOptions"] && [jsonItem[@"shippingOptions"] count] > 0) {
					// shippingInfo.shippingType
					NSString *shippingType = @"NotSpecified";
					if (!jsonItem[@"shippingOptions"][0][@"shippingCost"][@"currency"] && !jsonItem[@"shippingOptions"][0][@"shippingCost"][@"value"]) {
						shippingType = @"Free";
					} else if ([jsonItem[@"shippingOptions"][0][@"shippingCostType"] isEqualToString:@"FLAT"]) {
						shippingType = @"Flat";
					} else if ([jsonItem[@"shippingOptions"][0][@"shippingCostType"] isEqualToString:@"CALCULATED"]) {
						shippingType = @"Calculated";
					}

					itemBase[@"shippingType"] = shippingType;

					NSMutableDictionary *shippingInfo = [@{
						@"shippingType": shippingType,
					} mutableCopy];
					if (![shippingType isEqualToString:@"Free"]) {
						shippingInfo[@"shippingServiceCost"] = [[NSClassFromString(@"CurrencyAmount") alloc] initWithStringAmount:jsonItem[@"shippingOptions"][0][@"shippingCost"][@"value"] currencyID:jsonItem[@"shippingOptions"][0][@"shippingCost"][@"currency"]];
					}

					itemBase[@"shippingInfo"] = shippingInfo;
				}

				if (jsonItem[@"listingMarketplaceId"]) {
					itemBase[@"globalId"] = jsonItem[@"listingMarketplaceId"];
				}

				NSString *postalCode = jsonItem[@"itemLocation"][@"postalCode"];
				if (postalCode) {
					itemBase[@"postalCode"] = postalCode;
				}

				NSArray *categories = jsonItem[@"categories"];
				if ([categories count] > 1) {
					NSDictionary *cat = categories[1]; // meow :3
					NSString *catId = cat[@"categoryId"];
					NSString *catName = cat[@"categoryName"];
					if (catId && catName) {
						itemBase[@"secondaryCategory"] = @{
							@"categoryId": catId,
							@"categoryName": catName
						};
					}
				}


				// finish!
                [item setValue:itemBase forKey:@"itemInfo"];
				[item setItemOrigin:19];
				[item setApiType:1];
				[items addObject:item];
			}
			self.items = items;
			
			/// Now time for the rest of the body
			[self setValue:@{
				@"xmlns": @"http://www.ebay.com/marketplace/search/v1/services",
				@"ack": @"Success",
				@"version": @"1.13.0",
				@"timestamp":  [NSDate date],
				@"searchResult": @{
					@"count": @([self.items count]),
					@"items": self.items,
				},
				@"paginationOutput": @{
					@"entriesPerPage": @([result[@"limit"] intValue]),
					@"pageNumber": @([result[@"offset"] intValue]/[result[@"limit"] intValue]),
					@"totalEntries": @([result[@"total"] intValue]),
					@"totalPages": @([result[@"total"] intValue]/[result[@"limit"] intValue]),
				},
			} forKey:@"findItemsDict"];
			

		} else {
			NSLog(@"[EBayX] getting items has failed");
		}
		[self setAck:@"Success"];
	} else {
		NSLog(@"[EBayX] JSON parsing failed :(");
	}
}

// -(BOOL)success {
// 		void *callstack[128];
// 	int frames = backtrace(callstack, 128);
// 	char **symbols = backtrace_symbols(callstack, frames);
// 	NSMutableString *callstackString = [@"[EbayX] Callstack for xml builder:\n" mutableCopy];
// 	for (int i = 0; i < frames; i++) {
// 		[callstackString appendFormat:@"%s\n", symbols[i]];
// 	}
// 	NSLog(@"%@", callstackString);
	
// 	free(symbols);
	
// 	 BOOL a = %orig;
	
// 	NSLog(@"[DEBUG] did succeed? %hhd", a);

// 	return 1;
// }

%end