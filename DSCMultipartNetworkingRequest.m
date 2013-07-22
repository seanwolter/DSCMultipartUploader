#import "DSCMultipartNetworkingRequest.h"
#import "DSCMultipartContent_private.h"

@implementation DSCResponseData : NSObject
@end

@interface DSCMultipartNetworkingRequest()
@property (copy) NSString *sessionID;

- (DSCResponseData *)makeRequest:(NSMutableURLRequest *)request withError:(NSError *)error;
+ (NSString *)md5ForData:(NSData *)data;
@end

@implementation DSCMultipartNetworkingRequest

- (instancetype)initWithSessionID:(NSString *)sessionID
{
    self = [super init];
    if (self) {
        _sessionID = [sessionID copy];
    }
    return self;
}

- (DSCResponseData *)put:(NSURL *)url withParameters:(NSDictionary *)params body:(NSData *)body error:(NSError *)error
{
    DLog(@"Making request: %@",url);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:TIMEOUT];
    [request setHTTPShouldHandleCookies:NO];

    [request setHTTPMethod:@"PUT"];

    [request setValue:[self userAgent] forHTTPHeaderField:@"User-Agent"];

    if(self.sessionID && ![self.sessionID isEqualToString:@""]) {
        [request setValue:[NSString stringWithFormat:@"token %@", self.sessionID] forHTTPHeaderField:@"Authorization"];
    }

	[request addValue:params[PART_CONTENT_TYPE] forHTTPHeaderField:PART_CONTENT_TYPE];
    [request addValue:params[PART_NUMBER] forHTTPHeaderField:PART_NUMBER];
    [request addValue:params[PARTS_TOTAL] forHTTPHeaderField:PARTS_TOTAL];
    [request addValue:[DSCMultipartNetworkingRequest md5ForData:body] forHTTPHeaderField:PART_CONTENT_MD5];

    [request setHTTPBody:body];

    return [self makeRequest:request withError:error];
}

- (DSCResponseData *)makeRequest:(NSMutableURLRequest *)request withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    if (![NSURLConnection canHandleRequest:request]) {
        return nil;
    }

    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

    DSCResponseData *responseData = [[DSCResponseData alloc] init];
    responseData.data = data;
    responseData.response = response;

    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    return responseData;
}

-(NSString*)userAgent {
    NSString* version = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString* build = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    NSString* os = [UIDevice currentDevice].systemVersion;
    NSString* userAgent = [NSString stringWithFormat:@"dScout/%@(%@) iOS/%@",
                           version, build, os];
    return userAgent;
}

+ (NSString *)md5ForData:(NSData *)data
{
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(data.bytes, data.length, md5Buffer);

    // Convert unsigned char buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x",md5Buffer[i]];

    return output;
}

@end
