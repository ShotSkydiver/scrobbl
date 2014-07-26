
#import "PBMediaRemoteNotificationObserver.h"
#import "PBScrobbler.h"


@implementation PBMediaRemoteNotificationObserver

-(id)init{
    
    self = [super init];
    
    if (self) {

    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    
    lastTitle = [[NSString alloc] init];
    lastArtist = [[NSString alloc] init];
    lastUID = [[NSNumber alloc] initWithInt:1];
    }
    return self;
}

-(void)unregisterForNotifications{
    
    MRMediaRemoteUnregisterForNowPlayingNotifications();
}


-(void)trackDidChange{
    
    if (!isPlayingCompletion) {
        __weak PBMediaRemoteNotificationObserver *weakSelf = self;
        
        isPlayingCompletion = ^(Boolean isPlayingNow){
            PBMediaRemoteNotificationObserver *strongSelf = weakSelf;
            
            if (strongSelf)
                strongSelf->isPlaying = isPlayingNow;};
    }
    
    if (self.scrobbler.isPaused) {
        return;
    }
    
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information){
        info=(__bridge NSDictionary *)(information);
    });
    

    [info setValue:[self nowPlayingApplicationIdentifier] forKey:@"nowPlayingApplication"];
    
    NSDate *timestamp = [info objectForKey:(__bridge NSDate *)kMRMediaRemoteNowPlayingInfoTimestamp];
    if (!timestamp) {
        [info setValue:[NSDate date] forKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTimestamp];
    }
    
    if ([self canSendNowPlaying]) {
        [self.delegate sendNowPlayingWithInfo:info];
    }
    
    dispatch_queue_t scrobbleQueue = dispatch_queue_create("scrobble", 0);
    
    double duration;
    
    duration = [[info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDuration] doubleValue];
    
//    Old RemoteMedia versions do not report duration, so we wait 30 seconds before trying to scrobble.
    
    dispatch_time_t popTime;
    
    if (duration) {
        
        popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * duration * NSEC_PER_SEC));}
    
    else{
        
       popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC));
    }
    
    dispatch_after(popTime, scrobbleQueue, ^(void){
            if ([self canScrobble]) {
                [self.delegate scrobbleTrackWithInfo:info];
            }
        });
}

-(BOOL)canSendNowPlaying{
    
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), isPlayingCompletion);
    
    if (!isPlaying) {
        return NO;
    }
    
    if ([info objectForKey:(__bridge NSNumber *)kMRMediaRemoteNowPlayingInfoUniqueIdentifier]) {
    
            if ([[info objectForKey:(__bridge NSNumber *)kMRMediaRemoteNowPlayingInfoUniqueIdentifier] isEqualToNumber:lastUID]) {
                return NO;
        }
        
        lastUID = [info objectForKey:(__bridge NSNumber *)kMRMediaRemoteNowPlayingInfoUniqueIdentifier];
        
        didScrobble = NO;
        return YES;
    }
    
    if ([info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtist] && [info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle]) {
        
    
            if ([lastArtist isEqualToString:[info objectForKey:(__bridge NSString *)(kMRMediaRemoteNowPlayingInfoArtist)]] && [lastTitle isEqualToString:[info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle]]) {
                return NO;
        }
        
        lastTitle = [info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle];
        lastArtist = [info objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtist];
        
        didScrobble = NO;
        return YES;
    }
    
    return NO;
}

-(BOOL)canScrobble{
    
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), isPlayingCompletion);
    
    if (!isPlaying || didScrobble) {
        return NO;
    }
    
    didScrobble = YES;
    
    return YES;
}

-(NSString *)nowPlayingApplicationIdentifier{
    
    CFStringRef appID = SBSCopyNowPlayingAppBundleIdentifier();
    NSString *nowPlayingAppID = [(__bridge NSString *)appID copy];
    CFRelease(appID);
    return nowPlayingAppID;
}


@end
