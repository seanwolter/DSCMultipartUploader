#import "DSCMultipartContent.h"
#import "DSCMultipartContent_private.h"
#import "DSCMultipartUploader.h"
#import "DSCMultipartNetworkingRequest.h"

NSString *const PARAM_CONTENT_FRAGMENTS = @"fragments";

@interface DSCMultipartContent()
@property NSURL *remotePath;
@property NSURL *filePath;
@property NSData *fileData;

@property (copy) NSString *sessionID;
@property (copy) NSString *contentString;

@property NSUInteger fragmentSize;
@property NSUInteger totalFragments;
@property NSUInteger currentFragment;

@property (copy) NSString *errorString;

@end

@implementation DSCMultipartContent

- (instancetype)initWithFilePath:(NSURL *)filePath remotePath:(NSURL *)remotePath
{
    self = [super init];
    if (self) {
        _filePath = filePath;
        _remotePath = remotePath;
    }
    return self;
}

- (BOOL)isReady
{
    if (!self.fileData) {
        NSError *error;
        self.fileData = [NSData dataWithContentsOfURL:self.filePath options:NSDataReadingMappedAlways|NSDataReadingUncached error:&error];
        if (!self.fileData) {
            return NO;
        }
    }

    if (!self.contentString) {
        NSLog(@"content is missing contentString");
        return NO;
    }

    if (!self.sessionID) {
        NSLog(@"content is missing sessionID");
        return NO;
    }

    return YES;
}

- (void)startUploadInQueue:(NSOperationQueue *)queue withFragmentSize:(NSUInteger)fragmentSize
{
    self.fragmentSize = fragmentSize;
    if (fragmentSize < 1 || fragmentSize > MAX_FRAGMENT_SIZE) {
        self.fragmentSize = MAX_FRAGMENT_SIZE;
    }
    self.totalFragments = (NSUInteger)ceil((double)[self.fileData length] / (double)fragmentSize);
    self.currentFragment = 0;

    [self uploadNextFragmentInQueue:queue];
}

- (void)uploadNextFragmentInQueue:(NSOperationQueue *)queue
{
    //TODO - remember to check on this and memory usage
    [queue addOperationWithBlock:^{
        NSInteger responseCode = 0;
        for (int fails = 0; fails < 3; fails++) {
            responseCode = [self uploadCurrentFragment];
        }

        if (responseCode == 200) {
            [self uploadNextFragmentInQueue:queue];
        } else if (responseCode != 201) {
            NSDictionary *dict = @{@"statusCode" : @(responseCode), @"serverMessage" : self.errorString};
            [[NSNotificationCenter defaultCenter] postNotificationName:MULTIPART_ERROR_NOTIFICATION object:self userInfo:dict];
        }
    }];
}

- (NSRange)currentRange
{
    NSRange range;
    range.location = self.fragmentSize * self.currentFragment;

    if (self.currentFragment + 1 == self.totalFragments) {
        range.length = [self.fileData length] - range.location;
    } else {
        range.length = self.fragmentSize;
    }

    return range;
}

- (NSData *)currentDataFragment
{
    return [self.fileData subdataWithRange:[self currentRange]];
}

- (NSInteger)uploadCurrentFragment
{
    NSError *error;

    DSCMultipartNetworkingRequest *request = [[DSCMultipartNetworkingRequest alloc] initWithSessionID:self.sessionID];
    NSDictionary *params = @{PART_CONTENT_TYPE: self.contentString,
                             PARTS_TOTAL: [NSString stringWithFormat:@"%d",self.totalFragments],
                             PART_NUMBER: [NSString stringWithFormat:@"%d",[self currentFragment]]};

    DSCResponseData *responseData = [request put:self.remotePath withParameters:params body:[self currentDataFragment] error:error];

    NSData *data = responseData.data;
    if (![NSJSONSerialization isValidJSONObject:data]) {
        return responseData.response.statusCode;
    }

    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if ((responseData.response.statusCode == 200 || responseData.response.statusCode == 201) && [data length] > 0 ) {
        NSArray *completedFragmentsIds = responseDict[PARAM_CONTENT_FRAGMENTS];
        self.currentFragment = [[completedFragmentsIds lastObject] integerValue];
    } else {
        [self parseErrorMessageFromDictionary:responseDict];
    }

    return responseData.response.statusCode;
}

- (void)parseErrorMessageFromDictionary:(NSDictionary *)responseDict
{
    // Try and pull out error info from server response
    self.errorString = @"Unexpected server response";
    if (![responseDict isKindOfClass:[NSDictionary class]] ) {
        return;
    }

    NSString *message = responseDict[@"message"];
    if (![message isKindOfClass:[NSString class]]) {
        NSDictionary *errors = responseDict[@"errors"];

        if(![errors isKindOfClass:[NSDictionary class]]) {
            NSMutableString* concatenated = [NSMutableString new];
            [errors enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [concatenated appendFormat:@"%@: %@\n", key, obj];
            }];
            message = [concatenated stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }

    if([message length]) {
        self.errorString = message;
    }
}

@end
