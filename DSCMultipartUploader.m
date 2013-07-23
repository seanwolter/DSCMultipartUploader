#import "DSCMultipartUploader.h"
#import "DSCMultipartContent.h"
#import "DSCMultipartContent_private.h"

@interface DSCMultipartUploader() {
    NSError *_errorToReturn;
}
@property NSURL *filePath;
@property NSURL *remotePath;
@property (readwrite) BOOL isExecuting;
@property (readwrite) BOOL isFinished;
@property (readwrite) float progress;

@property DSCMultipartContent *content;

@property NSOperationQueue *privateQueue;
@property NSOperationQueue *runwayQueue;

@end

NSString * const ContentStringTypeJPEG = @"image/jpeg";
NSString * const ContentStringTypeVideo = @"video/mp4";
NSString *stringFromContentType(DSCMultipartContentType contentType)
{
    switch (contentType) {
        case DSCMultipartContentJPEG:
            return ContentStringTypeJPEG;
            break;
        case DSCMultipartContentVideo:
            return ContentStringTypeVideo;
            break;
        default:
            return @"";
            break;
    }
}

@implementation DSCMultipartUploader

#pragma mark - Private Queue
+ (NSOperationQueue *)sharedQueue
{
    static dispatch_once_t onceToken;
    static NSOperationQueue *sharedQueue;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
        sharedQueue.name = [NSString stringWithFormat:@"com.dscout.upload.%@",NSStringFromClass(self)];
        [sharedQueue setMaxConcurrentOperationCount:1];
    });

    return sharedQueue;
}

+ (NSOperationQueue *)runwayQueue
{
    static dispatch_once_t onceToken;
    static NSOperationQueue *runwayQueue;
    dispatch_once(&onceToken, ^{
        runwayQueue = [[NSOperationQueue alloc] init];
        runwayQueue.name = [NSString stringWithFormat:@"com.dscout.worker.%@",NSStringFromClass(self)];
        [runwayQueue setMaxConcurrentOperationCount:1];
    });

    return runwayQueue;
}

#pragma mark - Initialization
+ (instancetype)uploaderWithPath:(NSURL *)path destinationURL:(NSURL *)remotePath contentType:(DSCMultipartContentType)contentType
{
    return [[self alloc] initWithPath:path destinationURL:remotePath contentType:contentType];
}

- (instancetype)initWithPath:(NSURL *)path destinationURL:(NSURL *)remotePath contentType:(DSCMultipartContentType)contentType
{
    self = [self init];
    if (self) {
        _doneCallbacks = [NSMutableArray array];
        _failCallbacks = [NSMutableArray array];
        _alwaysCallbacks = [NSMutableArray array];
        _progress = 0.0;
        _isExecuting = NO;
        _isFinished = NO;
        _privateQueue = [[self class] sharedQueue];
        _runwayQueue = [[self class] runwayQueue];
        _filePath = path;
        _remotePath = remotePath;
        _content = [[DSCMultipartContent alloc] initWithFilePath:_filePath remotePath:_remotePath];
        [_content setContentString:stringFromContentType(contentType)];
    }
    return self;
}

- (void)setSessionID:(NSString *)sessionID
{
    self.content.sessionID = sessionID;
}

#pragma mark - Completion Block Handling
- (void)addDoneCallback:(multipartCompletionBlock)doneBlock
{
    [self.doneCallbacks addObject:doneBlock];
}

- (void)addFailCallback:(multipartFailBlock)failBlock
{
    [self.failCallbacks addObject:failBlock];
}

- (void)addAlwaysCallback:(multipartCompletionBlock)alwaysBlock
{
    [self.alwaysCallbacks addObject:alwaysBlock];
}

#pragma mark - Action Methods
- (void)start
{
    if ([self.privateQueue isSuspended]) {
        [self.privateQueue setSuspended:NO];
        self.isExecuting = YES;
        self.isFinished = NO;
    } else {
        //only one multipart upload will run at a time
        //the runway queue collects start-operations
        [self.runwayQueue addOperationWithBlock:^{
            [self.privateQueue waitUntilAllOperationsAreFinished];
            [self createOperationsAndBegin];
        }];
    }
}

- (void)pause
{
    [self.privateQueue setSuspended:YES];
    self.isExecuting = NO;
    self.isFinished = NO;
}

- (void)cancel
{
    [self.privateQueue cancelAllOperations];
    [self.content removeObserver:self forKeyPath:@"currentFragment"];
    self.isExecuting = NO;
    self.isFinished = NO;

    [self runAlwaysCallbacks]; //should always callbacks run if cancelled??
}

#pragma mark - Private Setup and Teardown
- (void)createOperationsAndBegin
{
    if (![self.content isReady]) {
        NSLog(@"content has not been initialized");
        return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadError:) name:MULTIPART_ERROR_NOTIFICATION object:self.content];
    [self.content addObserver:self forKeyPath:@"currentFragment" options:NSKeyValueObservingOptionNew context:nil];

    self.isExecuting = YES;
    [self.content startUploadInQueue:self.privateQueue withFragmentSize:MAX_FRAGMENT_SIZE];
}

- (void)operationsAreComplete
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MULTIPART_COMPLETE_NOTIFICATION object:self];
    [self.content removeObserver:self forKeyPath:@"currentFragment"];

    self.isExecuting = NO;
    self.isFinished = YES;

    [self runDoneCallbacks];
}

#pragma mark - KVO and Notifications
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.progress = (float)self.content.currentFragment/(float)self.content.totalFragments;
    if (self.content.currentFragment == self.content.totalFragments) {
        [self operationsAreComplete];
    }
}

- (void)uploadError:(NSNotification *)note
{
    NSString *errorMessage = [note.userInfo valueForKey:@"serverMessage"];
    NSNumber *statusCode = [note.userInfo valueForKey:@"statusCode"];

    self.isExecuting = NO;
    self.isFinished = NO;

    NSDictionary *dict = @{@"statusCode" : statusCode, @"serverMessage" : errorMessage};
    _errorToReturn = [NSError errorWithDomain:MULTIPART_ERROR_NOTIFICATION code:[statusCode integerValue] userInfo:dict];
    [self throwError];
}

#pragma mark - Private Completion Handling
- (void)runAlwaysCallbacks
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.alwaysCallbacks enumerateObjectsUsingBlock:^(multipartCompletionBlock block, NSUInteger idx, BOOL *stop) {
            block();
        }];
        [self.alwaysCallbacks removeAllObjects];
    });
}

- (void)runDoneCallbacks
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.doneCallbacks enumerateObjectsUsingBlock:^(multipartCompletionBlock block, NSUInteger idx, BOOL *stop) {
            block();
        }];
        [self.doneCallbacks removeAllObjects];
        [self runAlwaysCallbacks];
    });
}

- (void)throwError
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.failCallbacks enumerateObjectsUsingBlock:^(multipartFailBlock block, NSUInteger idx, BOOL *stop) {
            block(_errorToReturn);
        }];
        [self.failCallbacks removeAllObjects];
        [self runAlwaysCallbacks];
    });
}

@end
