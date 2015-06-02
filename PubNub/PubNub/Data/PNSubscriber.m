/**
 @author Sergey Mamontov
 @since 4.0
 @copyright © 2009-2015 PubNub, Inc.
 */
#import "PNSubscriber.h"
#import "PubNub+PresencePrivate.h"
#import "PNRequestParameters.h"
#import "PubNub+CorePrivate.h"
#import "PNStatus+Private.h"
#import "PNResult+Private.h"
#import "PNStateListener.h"
#import "PNConfiguration.h"
#import "PNClientState.h"
#import "PNHeartbeat.h"
#import "PNHelpers.h"


#pragma mark Static

/**
 @brief  Reference on time which should be used by retry timer as interval between subscription
 retry attempts.
 
 @since 4.0
 */
static NSTimeInterval const kPubNubSubscriptionRetryInterval = 1.0f;


#pragma mark - Structures

typedef NS_OPTIONS(NSUInteger, PNSubscriberState) {
    
    /**
     @brief  State set when subscriber has been just initialized.
     
     @since 4.0
     */
    PNInitializedSubscriberState,
    
    /**
     @brief  State set at the moment when client received response on 'leave' request and not 
             subscribed to any remote data objects live feed.
     
     @since 4.0
     */
    PNDisconnectedSubscriberState,
    
    /**
     @brief  State set at the moment when client lost connection or experienced other issues with
             communication etsablished with \b PubNub service.
     
     @since 4.0
     */
    PNDisconnectedUnexpectedlySubscriberState,
    
    /**
     @brief  State set at the moment when client received response with 200 status code for subcribe
             request with TT 0.
     
     @since 4.0
     */
    PNConnectedSubscriberState,
    
    /**
     @brief  State set at the moment when client received response with 403 status code for subcribe
             request.
     
     @since 4.0
     */
    PNAccessRightsErrorSubscriberState
};


#pragma mark - Protected interface declaration

@interface PNSubscriber ()


#pragma mark - Information

/**
 @brief  Weak reference on client for which subscribe manager manage subscribe loop.
 
 @since 4.0
 */
@property (nonatomic, weak) PubNub *client; 

/**
 @brief  Stores reference on current subscriber state.
 
 @since 4.0
 */
@property (nonatomic, assign) PNSubscriberState currentState;

/**
 @brief  Actual storage for list of channels on which client subscribed at this moment and listen 
         for updates from live feeds.
 
 @since 4.0
 */
@property (nonatomic, strong) NSMutableSet *channelsSet;

/**
 @brief  Actual storage for list of channel groups on which client subscribed at this moment and 
         listen for updates from live feeds.
 
 @since 4.0
 */
@property (nonatomic, strong) NSMutableSet *channelGroupsSet;

/**
 @brief  Actual storage for list of presence channels on which client subscribed at this moment and
         listen for presence updates.
 
 @since 4.0
 */
@property (nonatomic, strong) NSMutableSet *presenceChannelsSet;

/**
 @brief      Reference on time token which is used for current subscribe loop iteration.
 @discussion \b 0 for initial subscription loop and non-zero for long-poll requests.
 
 @since 4.0
 */
@property (nonatomic, strong) NSNumber *currentTimeToken;

/**
 @brief      Reference on time token which has been used for previous subscribe loop iteration.
 @discussion \b 0 for initial subscription loop and non-zero for long-poll requests.
 
 @since 4.0
 */
@property (nonatomic, strong) NSNumber *lastTimetoken;

/**
 @brief  Stores reference on queue which is used to serialize access to shared subscriber 
         information.
 
 @since 4.0
 */
@property (nonatomic, strong) dispatch_queue_t resourceAccessQueue;

/**
 @brief      Stores reference on GCD timer used to re-issue subscrbibe request.
 @discussion Timer activated in cases if previous subscribe loop failed with category type which
             can be temporary.
 
 @since 4.0
 */
@property (nonatomic, strong) dispatch_source_t retryTimer;


#pragma mark - Initialization and Configurtion

/**
 @brief  Initialize subscribe loop manager for concrete \b PubNub client.
 
 @param client Reference on client which will be weakly stored in subscriber.
 
 @return Initialized and ready to use subscribe manager instance.
 
 @since 4.0
 */
- (instancetype)initForClient:(PubNub *)client NS_DESIGNATED_INITIALIZER;


#pragma mark - Subscription information modification

/**
 @brief      Update current subscriber state.
 @discussion If possible, state transition will be reported to the listeners.
 
 @param state  New state from \b PNSubscriberState enum fields.
 @param status Reference on status object which should be passed along to listeners.
 
 @since 4.0
 */
- (void)updateStateTo:(PNSubscriberState)state withStatus:(PNStatus *)status;


#pragma mark - Subscription

/**
 @brief  Continue subscription cycle using \c currentTimeToken value and channels, stored in cache.
 
 @since 4.0
 */
- (void)continueSubscriptionCycleIfRequired;

/**
 @brief      Launch subscription retry timer.
 @discussion Launch timer with default 1 second interval after each subscribe attempt. In most of
             cases timer used to retry subscription after PubNub Access Manager denial because of
             client doesn't has enough rights.

 @since 4.0
 */
- (void)startRetryTimer;

/**
 @brief      Terminate previously launched subscription retry counter.
 @discussion In case if another subscribe request from user client better to stop retry timer to
             eliminate race of conditions.

 @since 4.0
 */
- (void)stopRetryTimer;


#pragma mark - Handlers

/**
 @brief      Handle subscription status update.
 @discussion Depending on passed status category and whether it is error it will be sent for 
             processing to corresponding methods.
 
 @param status Reference on status object which has been received from \b PubNub network.
 
 @since 4.0
 */
- (void)handleSubscriptionStatus:(PNStatus *)status;

/**
 @brief      Process successful subscription status.
 @discussion Success can be called as result of initial subscription successful ACK response as well 
             as long-poll response with events from remote data objects live feed.
 
 @param status Reference on status object which has been received from \b PubNub network.
 
 @since 4.0
 */
- (void)handleSuccessSubscriptionStatus:(PNStatus *)status;

/**
 @brief      Process failed subscription status.
 @discussion Failure can be cause by Access Denied error, network issues or called when last 
             subscribe request has been canceled (to execute new subscription for example).
 
 @param status Reference on status object which has been received from \b PubNub network.
 
 @since 4.0
 */
- (void)handleFailedSubscriptionStatus:(PNStatus *)status;

/**
 @brief  Handle subscription time token received from \b PubNub network.
 
 @param initialSubscription Whether subscription is initial or received time token on long-poll
                            request.
 @param timeToken           Reference on time token which has been received from \b PubNub nrtwork.
 
 @since 4.0
 */
- (void)handleSubscription:(BOOL)initialSubscription timeToken:(NSNumber *)timeToken;

/**
 @brief  Handle long-poll service response and deliver events to listeners if required.
 
 @param status Reference on status object which has been received from \b PubNub network.
 
 @since 4.0
 */
- (void)handleLiveFeedEvents:(PNStatus *)status;

/**
 @brief  Process message which just has been received from \b PubNub service through live feed on 
         which client subscribed at this moment.
 
 @param data      Reference on result data which hold information about request on which this 
                  response has been received and message itself.
 
 @since 4.0
 */
- (void)handleNewMessage:(PNResult *)data;

/**
 @brief  Process presence event which just has been receoved from \b PubNub service through presence
         live feeds on which client subscribed at this moment.
 
 @param data      Reference on result data which hold information about request on which this 
                  response has been received and presence event itself.
 
 @since 4.0
 */
- (void)handleNewPresenceEvent:(PNResult *)data;


#pragma mark - Misc

/**
 @brief  Compose request parameterts instance basing on current subscriber state.
 
 @param state Reference on merged client state which should be used in request.
 
 @return Configured and ready to use parameters instance.
 
 @since 4.0
 */
- (PNRequestParameters *)subscribeRequestParametersWithState:(NSDictionary *)state;

/**
 @brief  Append subscriber information to status object.
 
 @param status Reference on status object which should be updated with subscriber information.
 
 @since 4.0
 */
- (void)appendSubscriberInformation:(PNStatus *)status;

#pragma mark -


@end


#pragma mark - Interface implementation

@implementation PNSubscriber

@synthesize retryTimer = _retryTimer;


#pragma mark - Information

- (dispatch_source_t)retryTimer {
    
    __block dispatch_source_t retryTimer = nil;
    dispatch_sync(self.resourceAccessQueue, ^{
        
        retryTimer = self->_retryTimer;
    });
    
    return retryTimer;
}

- (void)setRetryTimer:(dispatch_source_t)retryTimer {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        self->_retryTimer = retryTimer;
    });
}


#pragma mark - State Information and Manipulation

- (NSArray *)allObjects {
    
    return [[[self channels] arrayByAddingObjectsFromArray:[self presenceChannels]]
            arrayByAddingObjectsFromArray:[self channelGroups]];
}

- (NSArray *)channels {
    
    __block NSArray *channels = nil;
    dispatch_sync(self.resourceAccessQueue, ^{
        
        channels = [self.channelsSet allObjects];
    });
    
    return channels;
}

- (void)addChannels:(NSArray *)channels {
    
    // Check whether channels list combined with presence channels or not.
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        NSArray *channelsOnly = [PNChannel objectsWithOutPresenceFrom:channels];
        if ([channelsOnly count] != [channels count]) {
            
            // Add presence channels to corresponding storage.
            NSMutableSet *channelsSet = [NSMutableSet setWithArray:channels];
            [channelsSet minusSet:[NSSet setWithArray:channelsOnly]];
            [self.presenceChannelsSet unionSet:channelsSet];
        }
        [self.channelsSet addObjectsFromArray:channelsOnly];
    });
}

- (void)removeChannels:(NSArray *)channels {
    
    // Check whether channels list combined with presence channels or not.
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        NSSet *channelsSet = [NSSet setWithArray:channels];
        [self.presenceChannelsSet minusSet:channelsSet];
        [self.channelsSet minusSet:channelsSet];
    });
}

- (NSArray *)channelGroups {
    
    __block NSArray *channelGroups = nil;
    dispatch_sync(self.resourceAccessQueue, ^{
        
        channelGroups = [self.channelGroupsSet allObjects];
    });
    
    return channelGroups;
}

- (void)addChannelGroups:(NSArray *)groups {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        [self.channelGroupsSet addObjectsFromArray:groups];
    });
}

- (void)removeChannelGroups:(NSArray *)groups {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        [self.channelGroupsSet minusSet:[NSSet setWithArray:groups]];
    });
}

- (NSArray *)presenceChannels {
    
    __block NSArray *presenceChannels = nil;
    dispatch_sync(self.resourceAccessQueue, ^{
        
        presenceChannels = [self.presenceChannelsSet allObjects];
    });
    
    return presenceChannels;
}

- (void)addPresenceChannels:(NSArray *)presenceChannels {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        [self.presenceChannelsSet addObjectsFromArray:presenceChannels];
    });
}

- (void)removePresenceChannels:(NSArray *)presenceChannels {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        [self.presenceChannelsSet minusSet:[NSSet setWithArray:presenceChannels]];
    });
}

- (void)updateStateTo:(PNSubscriberState)state withStatus:(PNStatus *)status {
    
    dispatch_barrier_async(self.resourceAccessQueue, ^{
        
        // Compose status object to report state change to listeners.
        PNStatusCategory category = PNUnknownCategory;
        PNSubscriberState targetState = state;
        PNSubscriberState currentState = self->_currentState;
        BOOL shouldHandleTransition = NO;
        
        // Check whether transit to 'connected' state.
        if (targetState == PNConnectedSubscriberState) {
            
            // Check whether client transit from 'disconnected' -> 'connected' state.
            shouldHandleTransition = (currentState == PNInitializedSubscriberState ||
                                      currentState == PNDisconnectedSubscriberState);
            
            // Check whether client transit from 'access denied' -> 'connected' state.
            if (!shouldHandleTransition) {
                
                shouldHandleTransition = (currentState == PNAccessRightsErrorSubscriberState);
            }
            category = PNConnectedCategory;
            
            // Check whether client transit from 'unexpected disconnect' -> 'connected' state
            if (!shouldHandleTransition && currentState == PNDisconnectedUnexpectedlySubscriberState) {
                
                // Change state to 'reconnected'
                targetState = PNConnectedSubscriberState;
                category = PNReconnectedCategory;
                shouldHandleTransition = YES;
            }
        }
        // Check whether transit to 'disconnected' or 'unexpected disconnect' state.
        else if (targetState == PNDisconnectedSubscriberState ||
                 targetState == PNDisconnectedUnexpectedlySubscriberState) {
            
            // Check whether client transit from 'connected' -> 'disconnected'/'unexpected disconnect'
            // state.
            shouldHandleTransition = (currentState == PNInitializedSubscriberState ||
                                      currentState == PNConnectedSubscriberState);
            category = ((targetState == PNDisconnectedSubscriberState) ? PNDisconnectedCategory :
                        PNUnexpectedDisconnectCategory);
            if (currentState == PNInitializedSubscriberState) {
                
                targetState = PNInitializedSubscriberState;
            }
        }
        // Check whether transit to 'access deined' state.
        else if (targetState == PNAccessRightsErrorSubscriberState) {
            
            // Check whether client transit from non-'access deined' -> 'access deined' state.
            shouldHandleTransition = YES;
            category = PNAccessDeniedCategory;
        }
        
        // Check whether allowed state transition has been issued or not.
        if (shouldHandleTransition) {
            
            self->_currentState = targetState;
            
            // Build status object in case if update has been called as transition between two
            // different states.
            PNStatus *targetStatus = status;
            if (!targetStatus) {
                
                targetStatus = [PNStatus statusForOperation:PNSubscribeOperation category:category];
            }
            [targetStatus updateCategory:category];
            [self appendSubscriberInformation:targetStatus];
            // Silence static analyzer warnings.
            // Code is aware about this case and at the end will simply call on 'nil' object method.
            // This instance is one of client properties and if client already deallocated there is
            // no need to this object which will be deallocated as well.
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wreceiver-is-weak"
            #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
            [self.client.listenersManager notifyWithBlock:^{
                
                [self.client.listenersManager notifyStatusChange:status];
            }];
            #pragma clang diagnostic pop
        }
    });
}


#pragma mark - Initialization and Configuration

+ (instancetype)subscriberForClient:(PubNub *)client {
    
    return [[self alloc] initForClient:client];
}

- (instancetype)initForClient:(PubNub *)client {
    
    // Check whether initialization was successful or not.
    if ((self = [super init])) {
        
        _client = client;
        _channelsSet = [NSMutableSet new];
        _channelGroupsSet = [NSMutableSet new];
        _presenceChannelsSet = [NSMutableSet new];
        _resourceAccessQueue = dispatch_queue_create("com.pubnub.subscriber",
                                                     DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}


#pragma mark - Subscription

- (void)subscribe:(BOOL)initialSubscribe withState:(NSDictionary *)state {
    
    [self stopRetryTimer];

    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    if ([[self allObjects] count]) {
        
        // In case if block is passed, it mean what subscription has been requested by user or
        // internal logic (like unsubscribe and re-subscribe on the rest of the channels/groups).
        if (initialSubscribe) {
            
            if ([self.currentTimeToken integerValue] > 0) {
                
                self.lastTimetoken = self.currentTimeToken;
            }
            self.currentTimeToken = @(0);
        }
        
        PNRequestParameters *parameters = [self subscribeRequestParametersWithState:state];
        __weak __typeof(self) weakSelf = self;
        [self.client processOperation:PNSubscribeOperation withParameters:parameters
                      completionBlock:^(PNStatus *status){
                          
                          [weakSelf handleSubscriptionStatus:status];
                      }];
    }
    else {
        
        PNStatus *status = [PNStatus statusForOperation:PNSubscribeOperation
                                               category:PNDisconnectedCategory];
        [self.client appendClientInformation:status];
        [self updateStateTo:PNDisconnectedSubscriberState withStatus:status];
        [self.client cancelAllLongPollingOperations];
        [self.client callBlock:nil status:YES withResult:nil andStatus:status];
    }
    #pragma clang diagnostic pop
}

- (void)restoreSubscriptionCycleIfRequired {
    
    __block BOOL shouldRestore;
    __block BOOL ableToRestore;
    dispatch_sync(self.resourceAccessQueue, ^{
        
        shouldRestore = (self.currentState == PNDisconnectedUnexpectedlySubscriberState &&
                         [self.currentTimeToken integerValue] > 0 &&
                         [self.lastTimetoken integerValue] > 0);
        ableToRestore = ([self.channelsSet count] || [self.channelGroupsSet count] ||
                         [self.presenceChannelsSet count]);
    });
    if (shouldRestore && ableToRestore) {
        
        [self subscribe:YES withState:nil];
    }
}

- (void)continueSubscriptionCycleIfRequired {

    [self subscribe:NO withState:nil];
}

- (void)unsubscribeFrom:(BOOL)channels objects:(NSArray *)objects {
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    [self.client.clientStateManager removeStateForObjects:objects];
    NSArray *objectWithOutPresence = [PNChannel objectsWithOutPresenceFrom:objects];
    PNStatus *successStatus = [PNStatus statusForOperation:PNUnsubscribeOperation
                                                  category:PNAcknowledgmentCategory];
    [self.client appendClientInformation:successStatus];
    
    if ([objectWithOutPresence count]) {
        
        NSString *objectsList = [PNChannel namesForRequest:objectWithOutPresence defaultString:@","];
        PNRequestParameters *parameters = [PNRequestParameters new];
        [parameters addPathComponent:objectsList forPlaceholder:@"{channels}"];
        if (!channels) {
            
            [parameters addQueryParameter:objectsList forFieldName:@"channel-group"];
        }
        __weak __typeof(self) weakSelf = self;
        [self.client processOperation:PNUnsubscribeOperation withParameters:parameters
                      completionBlock:^(__unused PNStatus *status){
                          
            [weakSelf updateStateTo:PNDisconnectedSubscriberState withStatus:successStatus];
            [weakSelf.client callBlock:nil status:YES withResult:nil andStatus:successStatus];
            [weakSelf subscribe:YES withState:nil];
        }];
    }
    else {
        
        [self updateStateTo:PNDisconnectedSubscriberState withStatus:successStatus];
        [self subscribe:YES withState:nil];
        [self.client callBlock:nil status:YES withResult:nil andStatus:successStatus];
    }
    #pragma clang diagnostic pop
}

- (void)startRetryTimer {
    
    [self stopRetryTimer];
    
    __weak __typeof(self) weakSelf = self;
    dispatch_queue_t timerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timerQueue);
    dispatch_source_set_event_handler(timer, ^{
        
        // Silence static analyzer warnings.
        // Code is aware about this case and at the end will simply call on 'nil' object method.
        // This instance is one of client properties and if client already deallocated there is
        // no need to this object which will be deallocated as well.
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wreceiver-is-weak"
        #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
        [weakSelf continueSubscriptionCycleIfRequired];
        #pragma clang diagnostic pop
    });
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPubNubSubscriptionRetryInterval * NSEC_PER_SEC));
    dispatch_source_set_timer(timer, start, (uint64_t)(kPubNubSubscriptionRetryInterval * NSEC_PER_SEC), NSEC_PER_SEC);
    self.retryTimer = timer;
    dispatch_resume(timer);
}

- (void)stopRetryTimer {
    
    dispatch_source_t timer = [self retryTimer];
    if (timer != NULL && dispatch_source_testcancel(timer) == 0) {
        
        dispatch_source_cancel(timer);
    }
    self.retryTimer = nil;
}


#pragma mark - Handlers

- (void)handleSubscriptionStatus:(PNStatus *)status {

    [self stopRetryTimer];
    if (!status.isError) {
        
        [self handleSuccessSubscriptionStatus:status];
    }
    else {
        
        [self handleFailedSubscriptionStatus:status];
    }
}

- (void)handleSuccessSubscriptionStatus:(PNStatus *)status {
    
    // Try fetch time token from passed result/status objects.
    NSNumber *timeToken = @([[status.clientRequest.URL lastPathComponent] longLongValue]);
    BOOL isInitialSubscription = ([timeToken integerValue] == 0);
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    if (status.data[@"tt"] != nil) {
        
        [self handleSubscription:(status.clientRequest.URL != nil && isInitialSubscription)
                       timeToken:status.data[@"tt"]];
    }
    
    [self handleLiveFeedEvents:status];
    [self continueSubscriptionCycleIfRequired];
    
    // Because client received new event from service, it can restart reachability timer with
    // new interval.
    [self.client.heartbeatManager startHeartbeatIfRequired];
    
    if (status.clientRequest.URL != nil && isInitialSubscription) {
        
        [self updateStateTo:PNConnectedSubscriberState withStatus:status];
        [self.client callBlock:nil status:YES withResult:nil andStatus:status];
    }
    #pragma clang diagnostic pop
}

- (void)handleFailedSubscriptionStatus:(PNStatus *)status {
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    // Looks like subscription request has been cancelled.
    // Cancelling can happen because of: user changed subscriber sensitive configuration or
    // another subscribe/unsubscribe request has been issued.
    if (status.category == PNCancelledCategory) {
        
        // Stop heartbeat for now and wait further actions.
        [self.client.heartbeatManager stopHeartbeatIfPossible];
    }
    // Looks like processing failed because of another error.
    // If there is another subscription/unsubscription operations is waiting client shouldn't
    // handle this status yet.
    else {
        
        // Check whether status category declare subscription retry or not.
        if (status.category == PNAccessDeniedCategory || status.category == PNTimeoutCategory ||
            status.category == PNMalformedResponseCategory ||
            status.category == PNTLSConnectionFailedCategory) {
            
            __weak __typeof(self) weakSelf = self;
            status.automaticallyRetry = YES;
            status.retryCancelBlock = ^{
                
                DDLogAPICall(@"<PubNub> Cancel retry");
                [weakSelf stopRetryTimer];
            };
            [self startRetryTimer];
            PNSubscriberState subscriberState = PNAccessRightsErrorSubscriberState;
            if (status.category != PNAccessDeniedCategory) {
                
                subscriberState = PNDisconnectedUnexpectedlySubscriberState;
                [status updateCategory:PNUnexpectedDisconnectCategory];
            }
            [self updateStateTo:subscriberState withStatus:status];
        }
        // Looks like client lost connection with internet or has any other connection
        // related issues.
        else {
            
            // Check whether subscription should be restored on network connection restore or
            // not.
            if (self.client.configuration.shouldRestoreSubscription) {
                
                status.automaticallyRetry = YES;
                status.retryCancelBlock = ^{
                    /* Do nothing, because we can't stop auto-retry in case of network issues.
                     It handled by client configuration. */ };
                if (self.client.configuration.shouldTryCatchUpOnSubscriptionRestore) {
                    
                    if ([self.currentTimeToken integerValue] > 0) {
                        
                        self.lastTimetoken = self.currentTimeToken;
                        self.currentTimeToken = @(0);
                    }
                }
                else {
                    
                    self.currentTimeToken = @(0);
                    self.lastTimetoken = @(0);
                }
            }
            else {
                
                // Ask to clean up cache associated with objects
                [self.client.clientStateManager removeStateForObjects:[self.channelsSet allObjects]];
                [self.client.clientStateManager removeStateForObjects:[self.channelGroupsSet allObjects]];
                self.channelsSet = [NSMutableSet new];
                self.channelGroupsSet = [NSMutableSet new];
                self.presenceChannelsSet = [NSMutableSet new];
            }
            [status updateCategory:PNUnexpectedDisconnectCategory];
            
            [self.client.heartbeatManager stopHeartbeatIfPossible];
            [self updateStateTo:PNDisconnectedUnexpectedlySubscriberState withStatus:status];
        }
    }
    [self.client callBlock:nil status:YES withResult:nil andStatus:status];
    #pragma clang diagnostic pop
}

- (void)handleSubscription:(BOOL)initialSubscription timeToken:(NSNumber *)timeToken {
    
    // Whether new time token from response should be applied for next subscription cycle or
    // not.
    BOOL shouldAcceptNewTimeToken = YES;
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    // 'shouldKeepTimeTokenOnListChange' property should never allow to reset time tokens in
    // case if there is a few more subscribe requests is waiting for their turn to be sent.
    if (initialSubscription && self.client.configuration.shouldKeepTimeTokenOnListChange) {
            
        // Ensure what we already don't use value from previous time token assigned during
        // previous sessions.
        if ([self.lastTimetoken integerValue] > 0) {
            
            shouldAcceptNewTimeToken = NO;
            
            // Swap time tokens to catch up on events which happened while client changed
            // channels and groups list configuration.
            self.currentTimeToken = self.lastTimetoken;
            self.lastTimetoken = @(0);
        }
    }
    #pragma clang diagnostic pop
    
    if (shouldAcceptNewTimeToken) {
        
        if ([self.currentTimeToken integerValue] > 0) {
            
            self.lastTimetoken = self.currentTimeToken;
        }
        self.currentTimeToken = timeToken;
    }
}

- (void)handleLiveFeedEvents:(PNStatus *)status {
    
    NSArray *events = [(NSArray *)status.data[@"events"] copy];
    if ([events count]) {
        
        // Silence static analyzer warnings.
        // Code is aware about this case and at the end will simply call on 'nil' object method.
        // This instance is one of client properties and if client already deallocated there is
        // no need to this object which will be deallocated as well.
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wreceiver-is-weak"
        #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
        [self.client.listenersManager notifyWithBlock:^{
            
            // Iterate through array with notifications and report back using callback blocks to the
            // user.
            for (NSMutableDictionary *event in events) {
                
                if (!event[@"subscribed_channel"]) {
                    
                    event[@"subscribed_channel"] = [self allObjects][0];
                }
                
                // Check whether event has been triggered on presence channel or channel group.
                // In case if check will return YES this is presence event.
                BOOL isPresenceEvent = ([PNChannel isPresenceObject:event[@"actual_channel"]] ||
                                        [PNChannel isPresenceObject:event[@"subscribed_channel"]]);
                if (isPresenceEvent) {
                    
                    if (event[@"subscribed_channel"]) {
                        
                        event[@"subscribed_channel"] = [PNChannel channelForPresence:event[@"subscribed_channel"]];
                    }
                    if (event[@"actual_channel"]) {
                        
                        event[@"actual_channel"] = [PNChannel channelForPresence:event[@"actual_channel"]];
                    }
                }
                
                PNResult *eventResultObject = [status copyWithMutatedData:event];
                if (isPresenceEvent) {
                    
                    [self handleNewPresenceEvent:eventResultObject];
                }
                else {
                    
                    [self handleNewMessage:eventResultObject];
                }
            }
        }];
        #pragma clang diagnostic pop
    }
    status.data = [(NSDictionary *)status.data dictionaryWithValuesForKeys:@[@"tt"]];
}

- (void)handleNewMessage:(PNResult *)data {
    
    PNStatus *status = nil;
    if (data) {
        
        DDLogResult(@"<PubNub> %@", [data stringifiedRepresentation]);
        if ([data.data[@"decryptError"] boolValue]) {
            
            status = [PNStatus statusForOperation:PNSubscribeOperation
                                         category:PNDecryptionErrorCategory];
            NSMutableDictionary *updatedData = [data.data mutableCopy];
            [updatedData removeObjectForKey:@"decryptError"];
            status.data = updatedData;
        }
    }
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    [self.client.listenersManager notifyMessage:data withStatus:status];
    #pragma clang diagnostic pop
}

- (void)handleNewPresenceEvent:(PNResult *)data {
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    // Check whether state modification event arrived or not.
    // In case of state modification event for current client it should be applied on local storage.
    if ([data.data[@"presence_event"] isEqualToString:@"state-change"]) {
        
        // Check whether state has been changed for current client or not.
        if ([data.data[@"presence"][@"uuid"] isEqualToString:self.client.configuration.uuid]) {
            
            NSString *object = (data.data[@"subscribed_channel"]?: data.data[@"actual_channel"]);
            [self.client.clientStateManager setState:data.data[@"presence"][@"state"] forObject:object];
        }
    }
    [self.client.listenersManager notifyPresenceEvent:data];
    #pragma clang diagnostic pop
}


#pragma mark - Misc

- (PNRequestParameters *)subscribeRequestParametersWithState:(NSDictionary *)state {
    
    // Compose full list of channels and groups stored in active subscription list.
    NSArray *channels = [[self channels] arrayByAddingObjectsFromArray:[self presenceChannels]];
    NSString *channelsList = [PNChannel namesForRequest:channels defaultString:@","];
    NSString *groupsList = [PNChannel namesForRequest:[self channelGroups]];
    NSArray *fullObjectsList = [channels arrayByAddingObjectsFromArray:[self channelGroups]];
    
    // Silence static analyzer warnings.
    // Code is aware about this case and at the end will simply call on 'nil' object method.
    // This instance is one of client properties and if client already deallocated there is
    // no need to this object which will be deallocated as well.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wreceiver-is-weak"
    #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    NSDictionary *mergedState = [self.client.clientStateManager stateMergedWith:state
                                                                     forObjects:fullObjectsList];
    [self.client.clientStateManager mergeWithState:mergedState];
    
    PNRequestParameters *parameters = [PNRequestParameters new];
    [parameters addPathComponent:channelsList forPlaceholder:@"{channels}"];
    [parameters addPathComponent:[self.currentTimeToken stringValue] forPlaceholder:@"{tt}"];
    if (self.client.configuration.presenceHeartbeatValue > 0 ) {
        
        [parameters addQueryParameter:[@(self.client.configuration.presenceHeartbeatValue) stringValue]
                         forFieldName:@"heartbeat"];
    }
    if ([groupsList length]) {
        
        [parameters addQueryParameter:groupsList forFieldName:@"channel-group"];
    }
    if ([mergedState count]) {
        
        NSString *mergedStateString = [PNJSON JSONStringFrom:mergedState withError:nil];
        if ([mergedStateString length]) {
            
            [parameters addQueryParameter:[PNString percentEscapedString:mergedStateString]
                             forFieldName:@"state"];
        }
    }
    #pragma clang diagnostic pop
    
    return parameters;
}

- (void)appendSubscriberInformation:(PNStatus *)status {
    
    status.currentTimetoken = self.currentTimeToken;
    status.lastTimetoken = self.lastTimetoken;
    status.subscribedChannels = [[self.channelsSet setByAddingObjectsFromSet:self.presenceChannelsSet] allObjects];
    status.subscribedChannelGroups = [self.channelGroupsSet allObjects];
}

#pragma mark -


@end
