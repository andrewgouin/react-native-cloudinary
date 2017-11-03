//
//  Cloudinary.m
//

#import "Cloudinary.h"

@implementation Cloudinary
@synthesize bridge = _bridge;
unsigned int CHUNKSIZE = 6000000;
unsigned int BUFFER_SIZE = 6000000;
AFHTTPSessionManager *manager;
- (instancetype)init
{
  self = [super init];
  if (self) {
    manager = [AFHTTPSessionManager manager];
  }
  return self;
}

+ (void) uploadChunk:(unsigned int) firstByte mUrl: (NSString *) mUrl mParams: (NSDictionary *) mParams mData: (NSData *) mData mFilename: (NSString *) mFilename mType: (NSString *) mType mUniqueId: (NSString *) mUniqueId lastByte: (unsigned int) lastByte shouldContinue: (bool) shouldContinue mResolve: (RCTPromiseResolveBlock) mResolve mReject: (RCTPromiseRejectBlock) mReject eventDispatcher: (RCTEventDispatcher *) eventDispatcher {
  
  NSString *posturl = [@"https://api.cloudinary.com/" stringByAppendingString:mUrl];
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
  NSString *contentRange = [@"bytes " stringByAppendingString:[[NSString stringWithFormat:@"%u", firstByte] stringByAppendingString:[@"-" stringByAppendingString:[[NSString stringWithFormat:@"%u", lastByte] stringByAppendingString:[@"/" stringByAppendingString:[NSString stringWithFormat:@"%lu", mData.length]]]]]];
  [manager.requestSerializer setValue:contentRange forHTTPHeaderField:@"Content-Range"];
  [manager.requestSerializer setValue:mUniqueId forHTTPHeaderField:@"X-Unique-Upload-Id"];
  RCTLogInfo(@"uploading chunk, firstByte: %u lastByte: %u chunkSize: %u", firstByte, lastByte, chunkSize );
  NSURLSessionTask *task = [manager POST:posturl parameters:mParams constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
    NSRange range = NSMakeRange(firstByte, chunkSize);
    NSData *chunk = [mData subdataWithRange:range];
    RCTLogInfo(@"data chunk size: %lu",chunk.length);
    [formData appendPartWithFileData:chunk name:@"file" fileName:mFilename mimeType:mType];
  }  progress:nil success:^(NSURLSessionTask *task, id responseObject) {
    NSLog(@"responseObject = %@", responseObject);
    float progress = 100.0 * lastByte / mData.length;
    [eventDispatcher sendDeviceEventWithName:@"uploadProgress"
                                                    body:@{@"progress": [NSNumber numberWithFloat:progress]}];
    if (shouldContinue) {
      [Cloudinary uploadChunk:lastByte + 1 mUrl:mUrl mParams:mParams mData:mData mFilename:mFilename mType:mType mUniqueId:mUniqueId lastByte:lastByte shouldContinue:shouldContinue mResolve:mResolve mReject:mReject eventDispatcher:eventDispatcher];
    } else {
      NSError *error;
      NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseObject
                                                         options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                           error:&error];
      if (! jsonData) {
        NSLog(@"Got an error: %@", error);
        mReject(@"Parse error", @"Error parsing cloudinary respnse", error);
      } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        mResolve(jsonString);
      }
    }
  } failure:^(NSURLSessionTask *task, NSError *error) {
    RCTLogInfo(@"error = %@", error);
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
  NSMutableDictionary * mParams = [[NSMutableDictionary alloc] initWithCapacity:6];
  
  if (signature != nil) {
    [mParams setValue:signature forKey:@"signature"];
  }
  if (apiKey != nil) {
    [mParams setValue:apiKey forKey:@"api_key"];
  }
  if (timestamp != nil) {
    [mParams setValue:timestamp forKey:@"timestamp"];
  }
  if (colors != nil) {
    [mParams setValue:colors forKey:@"colors"];
  }
  if (returnDeleteToken != nil) {
    [mParams setValue:returnDeleteToken forKey:@"return_delete_token"];
  }
  if (format != nil) {
    [mParams setValue:format forKey:@"format"];
  }
  
  RCTLogInfo(@"params: %@", mParams);
  NSString * uniqueId = [NSString stringWithFormat:@"Upload-%@", [[NSUUID UUID] UUIDString]];
  RCTLogInfo(@"uniqueId: %@", uniqueId);
  NSURL *nsuri = [[NSURL alloc] initWithString:uri];
  uri = [uri stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  PHAsset * asset = [[PHAsset fetchAssetsWithALAssetURLs:@[nsuri] options:nil] lastObject];
  if (asset) {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES;
    options.networkAccessAllowed = NO;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    if ([[type substringToIndex: 5] isEqualToString:@"video"]){
      PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
      options.version = PHVideoRequestOptionsVersionOriginal;
      
      [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
        if ([asset isKindOfClass:[AVURLAsset class]]) {
          NSURL *URL = [(AVURLAsset *)asset URL];
          NSData * mData = [NSData dataWithContentsOfURL:URL];
          [Cloudinary uploadChunk:0 mUrl:url mParams:mParams mData:mData mFilename:filename mType:type mUniqueId:uniqueId lastByte: 0 shouldContinue:true mResolve:resolve mReject:reject eventDispatcher:self.bridge.eventDispatcher];
        }
      }];
    } else {
      [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        NSNumber * isError = [info objectForKey:PHImageErrorKey];
        NSNumber * isCloud = [info objectForKey:PHImageResultIsInCloudKey];
        if ([isError boolValue] || [isCloud boolValue] || ! imageData) {
          RCTLogInfo(@"failed to get image data");
          reject(@"Read file failed", @"Failed to get data", nil);
        } else {
          RCTLogInfo(@"success! image data ready to stream");
          NSData* mData = imageData;
          [Cloudinary uploadChunk:0 mUrl:url mParams:mParams mData:mData mFilename:filename mType:type mUniqueId:uniqueId lastByte:0 shouldContinue:true mResolve:resolve mReject:reject eventDispatcher:self.bridge.eventDispatcher];
        }
      }];
    }
  } else {  //no asset, must be from google drive, dropbox, icloud drive, etc.
    if ([[uri substringWithRange:NSMakeRange(0, 7)] isEqualToString: @"file://"]) {
      uri = [uri substringFromIndex:7];
      RCTLogInfo(@"file:// removed from uri, new uri: %@", uri);
    }    
    RCTLogInfo(@"uri: %@",uri);
    NSError *error;
    NSData * mData = [NSData dataWithContentsOfFile:uri options: 0 error: &error];
    if (mData == nil){
      reject(@"Unable to read file", @"Failed to get contents of file", error);
      RCTLogInfo(@"error getting contents of file: %@", error);
    } else {
      [Cloudinary uploadChunk:0 mUrl:url mParams:mParams mData:mData mFilename:filename mType:type mUniqueId:uniqueId lastByte:0 shouldContinue:true mResolve:resolve mReject:reject eventDispatcher:self.bridge.eventDispatcher];
    }
  }
}
@end
