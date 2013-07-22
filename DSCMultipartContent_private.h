#import "DSCMultipartContent.h"

NSUInteger const MAX_FRAGMENT_SIZE = 56000;

float const TIMEOUT = 30.0;
NSString *const PART_CONTENT_TYPE = @"Content-Type";
NSString *const PART_NUMBER = @"Part-Number";
NSString *const PARTS_TOTAL = @"Parts-Total";
NSString *const PART_CONTENT_MD5 = @"Content-MD5";

@interface DSCMultipartContent (DSCMultipartContent_private)

- (instancetype)initWithFilePath:(NSURL *)filePath remotePath:(NSURL *)remotePath;

- (NSUInteger)currentFragment;
- (NSUInteger)totalFragments;

- (void)setSessionID:(NSString *)sessionID;
- (void)setContentString:(NSString*)contentString;

@end
