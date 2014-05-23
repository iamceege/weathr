//
//  WXManager.m
//  Weather
//
//  Created by Caleb Jacob on 5/20/14.
//  Copyright (c) 2014 Caleb Jacob. All rights reserved.
//

#import "WXManager.h"
#import "WXClient.h"
#import <TSMessages/TSMessage.h>

@interface WXManager ()

@property (nonatomic, strong, readwrite) WXCondition *currentCondition;
@property (nonatomic, strong, readwrite) CLLocation *currentLocation;
@property (nonatomic, strong, readwrite) NSArray *hourlyForecast;
@property (nonatomic, strong, readwrite) NSArray *dailyForecast;
@property (nonatomic, strong, readwrite) NSString *backgroundImage;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, strong) WXClient *client;

@end

@implementation WXManager

+ (instancetype)sharedManager {
    static id _sharedManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

- (id)init {
    if (self = [super init]) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _client = [[WXClient alloc] init];
        
        [[[[RACObserve(self, currentLocation) ignore:nil] flattenMap:^(CLLocation *newLocation) {
            return [RACSignal merge: @[
                                       [self updateCurrentConditions],
                                       [self updateDailyForecast],
                                       [self updateHourlyForecast]
                                       ]];
        }] deliverOn:RACScheduler.mainThreadScheduler] subscribeError:^(NSError *error) {
            [TSMessage showNotificationWithTitle:@"Whoops"
                                        subtitle:@"Can't has weather."
                                            type:TSMessageNotificationTypeError];
        }];
    }
    
    return self;
}

- (void)findCurrentLocation {
    self.isFirstUpdate = YES;
    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (self.isFirstUpdate) {
        self.isFirstUpdate = NO;
        return;
    }
    
    NSLog(@"%@", locations);
    
    CLLocation *location = [locations lastObject];
    
    if (location.horizontalAccuracy > 0) {
        self.currentLocation = location;
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Error while getting core location : %@",[error localizedFailureReason]);
    NSLog(@"%ld", (long)[error code]);
    [manager stopUpdatingLocation];
}

- (RACSignal *)updateCurrentConditions {
    return [[self.client fetchCurrentConditionsForLocation:self.currentLocation.coordinate] doNext:^(WXCondition *condition) {
        self.currentCondition = condition;
        
        [[[self updateBackgroundImage] deliverOn:RACScheduler.mainThreadScheduler] subscribeError:^(NSError *error) {
            [TSMessage showNotificationWithTitle:@"Whoops"
                                        subtitle:@"Can't fetch background image."
                                            type:TSMessageNotificationTypeError];
        }];
    }];
}

- (RACSignal *)updateHourlyForecast {
    return [[self.client fetchHourlyForecastForLocation:self.currentLocation.coordinate] doNext:^(NSArray *conditions) {
        self.hourlyForecast = conditions;
    }];
}

- (RACSignal *)updateDailyForecast {
    return [[self.client fetchDailyForecastForLocation:self.currentLocation.coordinate] doNext:^(NSArray *conditions) {
        self.dailyForecast = conditions;
    }];
}

- (RACSignal *)updateBackgroundImage {    
    return [[self.client fetchImageForConditions:self.currentCondition.condition atLocation:self.currentCondition.locationName] doNext:^(id image) {
        self.backgroundImage = image;
    }];
}

@end
