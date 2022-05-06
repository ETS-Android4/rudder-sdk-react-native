#import "RudderIntegrationAppsflyerReactNative.h"
#import <RNRudderSdk/RNRudderAnalytics.h>
#import <Rudder-Appsflyer/RudderAppsflyerFactory.h>

@implementation RudderIntegrationAppsflyerReactNative

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(setup: (NSString*)devKey withDebug: (BOOL) isDebug withConversionDataListener: (BOOL) onInstallConversionDataListener withDeepLinkListener: (BOOL) onDeepLinkListener withAppleAppId: (NSString*) appleAppId) 
{
    [[AppsFlyerLib shared] setAppsFlyerDevKey:devKey];
    [[AppsFlyerLib shared] setAppleAppID:appleAppId];
    if(isDebug) {
        [AppsFlyerLib shared].isDebug = YES;
    }
    if(onInstallConversionDataListener) {
      [AppsFlyerLib shared].delegate = self;
    }
    if(onDeepLinkListener) {
       [AppsFlyerLib shared].deepLinkDelegate = self;
    }
    //post notification for the deep link object that the bridge is initialized and he can handle deep link
    [[AppsFlyerAttribution shared] setRNAFBridgeReady:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:RNAFBridgeInitializedNotification object:self];
    // Register for background-foreground transitions natively instead of doing this in JavaScript
    // [[NSNotificationCenter defaultCenter] addObserver:self
    //                                             selector:@selector(sendLaunch:)
    //                                                 name:UIApplicationDidBecomeActiveNotification
    //                                             object:nil];
    [[AppsFlyerLib shared] start];
    [RNRudderAnalytics addIntegration:[RudderAppsflyerFactory instance]];
}

RCT_EXPORT_METHOD(getAppsFlyerId:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *appsflyerId = [AppsFlyerLib shared].getAppsFlyerUID;
    resolve(appsflyerId);
}

- (void)didResolveDeepLink:(AppsFlyerDeepLinkResult* _Nonnull) result {
    NSString *deepLinkStatus = nil;
    switch(result.status) {
        case AFSDKDeepLinkResultStatusFound:
            deepLinkStatus = @"FOUND";
            break;
        case AFSDKDeepLinkResultStatusNotFound:
            deepLinkStatus = @"NOT_FOUND";
            break;
        case AFSDKDeepLinkResultStatusFailure:
            deepLinkStatus = @"ERROR";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected FormatType."];
    }
        NSMutableDictionary* message = [[NSMutableDictionary alloc] initWithCapacity:5];
        message[@"status"] = ([deepLinkStatus isEqual:@"ERROR"] || [deepLinkStatus isEqual:@"NOT_FOUND"]) ? afFailure : afSuccess;
        message[@"deepLinkStatus"] = deepLinkStatus;
        message[@"type"] = afOnDeepLinking;
        message[@"isDeferred"] = result.deepLink.isDeferred ? @YES : @NO;
        if([deepLinkStatus  isEqual: @"ERROR"]){
            message[@"data"] = result.error.localizedDescription;
        }else if([deepLinkStatus  isEqual: @"NOT_FOUND"]){
            message[@"data"] = @"deep link not found";
        }else{
            message[@"data"] = result.deepLink.clickEvent;
        }

    [self performSelectorOnMainThread:@selector(handleCallback:) withObject:message waitUntilDone:NO];
}

-(void)onConversionDataSuccess:(NSDictionary*) installData {
    NSDictionary* message = @{
        @"status": afSuccess,
        @"type": afOnInstallConversionDataLoaded,
        @"data": [installData copy]
    };

    [self performSelectorOnMainThread:@selector(handleCallback:) withObject:message waitUntilDone:NO];
}


-(void)onConversionDataFail:(NSError *) _errorMessage {
    NSLog(@"[DEBUG] AppsFlyer = %@",_errorMessage.localizedDescription);
    NSDictionary* errorMessage = @{
        @"status": afFailure,
        @"type": afOnInstallConversionFailure,
        @"data": _errorMessage.localizedDescription
    };

    [self performSelectorOnMainThread:@selector(handleCallback:) withObject:errorMessage waitUntilDone:NO];

}


- (void) onAppOpenAttribution:(NSDictionary*) attributionData {
    NSDictionary* message = @{
        @"status": afSuccess,
        @"type": afOnAppOpenAttribution,
        @"data": attributionData
    };
    [self performSelectorOnMainThread:@selector(handleCallback:) withObject:message waitUntilDone:NO];
}

- (void) onAppOpenAttributionFailure:(NSError *)_errorMessage {
    NSLog(@"[DEBUG] AppsFlyer = %@",_errorMessage.localizedDescription);
    NSDictionary* errorMessage = @{
        @"status": afFailure,
        @"type": afOnAttributionFailure,
        @"data": _errorMessage.localizedDescription
    };
    [self performSelectorOnMainThread:@selector(handleCallback:) withObject:errorMessage waitUntilDone:NO];
}


-(void) handleCallback:(NSDictionary *) message {
    NSError *error;

    if ([NSJSONSerialization isValidJSONObject:message]) {
        NSData *jsonMessage = [NSJSONSerialization dataWithJSONObject:message
                                                              options:0
                                                                error:&error];
        if (jsonMessage) {
            NSString *jsonMessageStr = [[NSString alloc] initWithBytes:[jsonMessage bytes] length:[jsonMessage length] encoding:NSUTF8StringEncoding];

            NSString* status = (NSString*)[message objectForKey: @"status"];
            NSString* type = (NSString*)[message objectForKey: @"type"];

            if([status isEqualToString:afSuccess]){
                [self reportOnSuccess:jsonMessageStr type:type];
            }
            else{
                [self reportOnFailure:jsonMessageStr type:type];
            }

            NSLog(@"jsonMessageStr = %@",jsonMessageStr);
        } else {
            NSLog(@"%@",error);
        }
    }
    else{
        NSLog(@"failed to parse Response");
    }
}

-(void) reportOnFailure:(NSString *)errorMessage type:(NSString*) type {
    @try {
        [self sendEventWithName:type body:errorMessage];
    } @catch (NSException *exception) {
        NSLog(@"AppsFlyer Debug: %@", exception);
    }
}

-(void) reportOnSuccess:(NSString *)data type:(NSString*) type {
    @try {
        [self sendEventWithName:type body:data];
    } @catch (NSException *exception) {
        NSLog(@"AppsFlyer Debug: %@", exception);
    }
}

- (NSArray<NSString *> *)supportedEvents {
    return @[afOnAttributionFailure,afOnAppOpenAttribution,afOnInstallConversionFailure, afOnInstallConversionDataLoaded, afOnDeepLinking];
}

@end
