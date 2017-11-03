//
//  Orientation.h
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AFNetworking/AFNetworking.h>
#import <UIKit/UIKit.h>
#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#else
#import "RCTBridgeModule.h"
#endif

@interface Cloudinary: NSObject <RCTBridgeModule>
+ (void) uploadChunk:(unsigned int) firstByte mUrl: (NSString *) mUrl mParams: (NSDictionary *) mParams mData: (NSData *) mData mFilename: (NSString *) mFilename mType: (NSString *) mType mUniqueId: (NSString *) mUniqueId lastByte: (unsigned int) lastByte shouldContinue: (bool) shouldContinue mResolve: (RCTPromiseResolveBlock) mResolve mReject: (RCTPromiseRejectBlock) mReject eventDispatcher: (RCTEventDispatcher *) eventDispatcher;
@end
