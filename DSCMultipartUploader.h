#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, DSCMultipartContentType) {
    DSCMultipartContentJPEG,
    DSCMultipartContentVideo
};

typedef void(^multipartCompletionBlock)(void);
typedef void(^multipartFailBlock)(NSError *error);

NSString * const MULTIPART_ERROR_NOTIFICATION = @"com.dscout.upload.error";
NSString * const MULTIPART_COMPLETE_NOTIFICATION = @"com.dscout.upload.success";

@interface DSCMultipartUploader : NSObject

- (void)setSessionID:(NSString *)sessionID;

/**
 Return an uploader with the given path. To conserve memory the uploader will only load a file path to data as needed.
 @param path The file path of the content to upload
 @param contentType The type of content.
 */
+ (instancetype)uploaderWithPath:(NSURL *)path
                  destinationURL:(NSURL *)remotePath
                     contentType:(DSCMultipartContentType)contentType;

- (instancetype)initWithPath:(NSURL *)path
              destinationURL:(NSURL *)remotePath
                 contentType:(DSCMultipartContentType)contentType;

///Returns YES while multipart upload is in-progress
@property (readonly) BOOL isExecuting;
///Returns NO until uploads are complete
@property (readonly) BOOL isFinished;
///Progress goes from 0.0 to 1.0
@property (readonly) float progress;

/** Completion Block Collections
 You cannot replace the entire array, but you can replace and remove the completion blocks to run.
 */
@property (readonly) NSMutableArray *doneCallbacks;
@property (readonly) NSMutableArray *failCallbacks;
@property (readonly) NSMutableArray *alwaysCallbacks;

/** Completion Blocks
 These are optional parameters. You can add multiple blocks for each outcome.
 The blocks run in the order they were added. You can add the same block multiple times.
 These run on the main queue.
 */
///Done block runs after a successful multipart upload
- (void)addDoneCallback:(multipartCompletionBlock)doneBlock;
///Fail block runs after a multipart upload fails
- (void)addFailCallback:(multipartFailBlock)failBlock;
///Always block runs at the end of a multipart upload regardless of success of failure
- (void)addAlwaysCallback:(multipartCompletionBlock)alwaysBlock;

/** Activity Methods
 These methods start, pause, and cancel the multipart upload.
 Depending on timing an additional chunk may upload before obeying pause or cancel.
 */
- (void)start;
- (void)pause;
- (void)cancel;

@end
