#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

@interface DSCResponseData : NSObject
@property NSData *data;
@property NSHTTPURLResponse *response;
@end

@interface DSCMultipartNetworkingRequest : NSObject

- (instancetype)initWithSessionID:(NSString *)sessionID;

- (DSCResponseData *)put:(NSURL *)url withParameters:(NSDictionary *)params body:(NSData *)body error:(NSError *)error;

@end

