#import <Foundation/Foundation.h>

@interface DSCMultipartContent : NSObject
- (BOOL)isReady;
- (void)startUploadInQueue:(NSOperationQueue *)queue withFragmentSize:(NSUInteger)fragmentSize;
@end
