//
//  Cloudinary.m
//

#import "Cloudinary.h"

#if __has_include(<React/RCTEventDispatcher.h>)
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#else
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#endif

@implementation Cloudinary
unsigned int CHUNKSIZE = 6000000;
NSString* mUrl;
NSDictionary *mParams;
NSData *mData;
NSString *mFilename;
NSString *mType;
unsigned int lastByte;
bool shouldContinue = true;
RCTPromiseResolveBlock mResolve;
RCTPromiseRejectBlock mReject;
+ (void) uploadChunk:(unsigned int) firstByte {
  
  AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
  NSString *posturl = [@"https://api.cloudinary.com/" stringByAppendingString:mUrl];
  NSURLSessionTask *task = [manager POST:posturl parameters:mParams constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
    unsigned int chunkSize;
    if (firstByte + CHUNKSIZE > mData.length) {
      chunkSize = mData.length - firstByte;
      lastByte = mData.length - 1;
      shouldContinue = false;
    } else {
      lastByte = firstByte + CHUNKSIZE - 1;
      chunkSize = CHUNKSIZE;
      shouldContinue = true;
    }
    RCTLogInfo(@"uploading chunk, firstByte: %u lastByte: %u chunkSize: %u", firstByte, lastByte, chunkSize );
    NSRange range = NSMakeRange(firstByte, chunkSize);
    NSData *chunk = [mData subdataWithRange:range];
    RCTLogInfo(@"data chunk size: %u",chunk.length);
    [formData appendPartWithFileData:chunk name:@"file" fileName:mFilename mimeType:mType];
  }  progress:nil success:^(NSURLSessionTask *task, id responseObject) {
    NSLog(@"responseObject = %@", responseObject);
    if (shouldContinue) {
      [Cloudinary uploadChunk: lastByte + 1];
    } else {
      mResolve(responseObject);
    }
  } failure:^(NSURLSessionTask *task, NSError *error) {
    NSLog(@"error = %@", error);
    mReject(@"Cloudinary error", @"Cloudinary upload failed" ,error);
  }];
  
  if (!task) {
    NSLog(@"Creation of task failed.");
    mReject(@"Creation of task failed", @"AFNetworking task creation failed", @"");
  }
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(upload:(NSString *)url uri: (NSString *)uri filename: (NSString *)filename signature: (NSString *) signature apiKey: (NSString *)apiKey timestamp: (NSString*)timestamp colors: (NSString *)colors returnDeleteToken: (NSString *)returnDeleteToken format: (NSString *)format type: (NSString *)type resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  //RCTLogInfo(@"Upload: url: %@ uri: %@ filename: %@ signature: %@ apiKey: %@ timestamp: %@ colors: %@ returnDeleteToken: %@ format: %@ type: %@", url, uri, filename, signature, apiKey, timestamp, colors, returnDeleteToken, format, type);
  mParams = @{@"signature"     : signature,
                           @"apiKey"    : apiKey,
                           @"timestamp" : timestamp,
                           @"colors"    : colors,
                           @"returnDeleteToken" : returnDeleteToken
                           };
  mFilename = filename;
  mType = type;
  mUrl = url;
  mResolve = resolve;
  mReject = reject;
  
  if (format != nil) {
    [mParams setValue:format forKey:@"format"];
  }
  
  RCTLogInfo(@"params: %@", mParams);
  NSString *uniqueId = [NSString stringWithFormat:@"Upload-%@", [[NSUUID UUID] UUIDString]];
  RCTLogInfo(@"uniqueId: %@", uniqueId);
  NSURL *nsuri = [[NSURL alloc] initWithString:uri];
  PHAsset * asset = [[PHAsset fetchAssetsWithALAssetURLs:@[nsuri] options:nil] lastObject];
  if (asset) {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES;
    options.networkAccessAllowed = NO;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
      NSNumber * isError = [info objectForKey:PHImageErrorKey];
      NSNumber * isCloud = [info objectForKey:PHImageResultIsInCloudKey];
      if ([isError boolValue] || [isCloud boolValue] || ! imageData) {
        RCTLogInfo(@"failed to get image data");
        mReject(@"Read file failed", @"Failed to get data", @"");
      } else {
        RCTLogInfo(@"success! image data ready to stream");
        mData = imageData;
        [Cloudinary uploadChunk: 0];
      }
    }];
  }
}

@end
