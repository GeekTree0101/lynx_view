#import "LynxImageRequestCancellation.h"

#import <Lynx/LynxNinePatchImageProcessor.h>
#import <Lynx/LynxResourceFetcher.h>
#import <LynxService/LynxImageService.h>
#import <SDWebImage/SDWebImage.h>
#import <objc/runtime.h>

#pragma mark - Request token

@class LynxImageRequestBag;

/// One request: the SDWebImage operation it started and whether it was
/// cancelled. The cancel block Lynx keeps holds it strongly; the bag on the
/// `LynxUIImage` holds it until it finishes.
@interface LynxImageRequestToken : NSObject
@property(atomic, assign, readonly) BOOL cancelled;
@property(atomic, weak) SDWebImageCombinedOperation *operation;
@property(atomic, weak) LynxImageRequestBag *bag;
- (void)cancel;
- (void)finish;
@end

/// Requests still running for one `LynxUIImage`, attached to it as an
/// associated object. Associated objects go after the owner's own ivars —
/// the cancel blocks Lynx keeps are already gone by then — so the bag holds
/// the tokens strongly and cancels what is left when it goes.
@interface LynxImageRequestBag : NSObject
- (void)add:(LynxImageRequestToken *)token;
- (void)remove:(LynxImageRequestToken *)token;
@end

@implementation LynxImageRequestToken {
  BOOL _cancelled;
}

- (BOOL)cancelled {
  @synchronized(self) {
    return _cancelled;
  }
}

- (void)cancel {
  @synchronized(self) {
    _cancelled = YES;
  }
  [self.operation cancel];
  [self finish];
}

- (void)finish {
  [self.bag remove:self];
}

@end

@implementation LynxImageRequestBag {
  NSMutableSet<LynxImageRequestToken *> *_tokens;
}

- (instancetype)init {
  if (self = [super init]) {
    _tokens = [NSMutableSet set];
  }
  return self;
}

- (void)add:(LynxImageRequestToken *)token {
  @synchronized(self) {
    [_tokens addObject:token];
  }
}

- (void)remove:(LynxImageRequestToken *)token {
  @synchronized(self) {
    [_tokens removeObject:token];
  }
}

- (void)dealloc {
  NSArray<LynxImageRequestToken *> *left;
  @synchronized(self) {
    left = [_tokens allObjects];
    [_tokens removeAllObjects];
  }
  for (LynxImageRequestToken *token in left) {
    [token cancel];
  }
}

@end

static const void *kRequestBagKey = &kRequestBagKey;

static LynxImageRequestBag *RequestBagOf(id owner) {
  @synchronized(owner) {
    LynxImageRequestBag *bag = objc_getAssociatedObject(owner, kRequestBagKey);
    if (bag == nil) {
      bag = [LynxImageRequestBag new];
      objc_setAssociatedObject(owner, kRequestBagKey, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
  }
}

#pragma mark - Loader

typedef dispatch_block_t (*LoadNewImageIMP)(id, SEL, LynxURL *, CGSize, BOOL, NSDictionary *,
                                            NSArray *, LynxImageLoadCompletionBlock, LynxUIImage *);

static LoadNewImageIMP gStockLoadNewImage = NULL;
static BOOL gEnabled = NO;

static UIImage *RunNinePatchProcessors(NSArray *processors, UIImage *image) {
  UIImage *processed = image;
  for (id<LynxImageProcessor> processor in processors) {
    processed = [processor processImage:processed];
  }
  return processed;
}

/// The stock `LynxImageService` loader (LynxService/Image 4.0.0
/// `loadNewImageFromURL:…`) with one difference: it keeps the operation it
/// starts, so the block it returns can cancel it. Everything else — URL
/// redirection, priority, downsampling, animated images, processors — follows
/// the stock code line for line. Keep the two in step when Lynx is upgraded.
static dispatch_block_t CancellableLoadNewImage(id self, SEL _cmd, LynxURL *requestUrl,
                                                CGSize targetSize, BOOL enableGenericFetcher,
                                                NSDictionary *contextInfo, NSArray *processors,
                                                LynxImageLoadCompletionBlock completed,
                                                LynxUIImage *lynxImage) {
  if (!LynxImageRequestCancellation.enabled) {
    return gStockLoadNewImage(self, _cmd, requestUrl, targetSize, enableGenericFetcher,
                              contextInfo, processors, completed, lynxImage);
  }

  LynxUI *lynxUI = nil;
  id callerUI = [contextInfo objectForKey:LynxImageFetcherContextKeyUI];
  if ([callerUI isKindOfClass:[LynxUI class]]) {
    lynxUI = callerUI;
  }
  NSString *urlStr = requestUrl.url.absoluteString;
  BOOL isBase64 = [urlStr hasPrefix:@"data:image"];
  BOOL shouldSkipRedirection = [[contextInfo objectForKey:LynxImageSkipRedirection] boolValue];
  if (!isBase64 && !shouldSkipRedirection && enableGenericFetcher) {
    LynxResourceOptionalBool isLocalResource = LynxResourceOptionalBoolUndefined;
    if ([lynxUI.context.mediaResourceFetcher respondsToSelector:@selector(isLocalResource:)]) {
      isLocalResource = [lynxUI.context.mediaResourceFetcher isLocalResource:requestUrl.url];
    }
    if (lynxUI && requestUrl.request && isLocalResource != LynxResourceOptionalBoolFalse) {
      urlStr = [lynxUI.context.mediaResourceFetcher shouldRedirectUrl:requestUrl.request];
    }
  }
  if ([urlStr hasPrefix:@"Resource/"]) {
    NSString *imagePath =
        [[NSBundle mainBundle] pathForResource:[urlStr stringByDeletingPathExtension]
                                        ofType:[urlStr pathExtension]];
    if (imagePath) {
      requestUrl.redirectedURL = [NSURL fileURLWithPath:imagePath];
    }
  } else if (isBase64 || [urlStr isEqualToString:requestUrl.url.absoluteString]) {
    requestUrl.redirectedURL = requestUrl.url;
  } else {
    requestUrl.redirectedURL = [NSURL URLWithString:urlStr];
  }

  SDWebImageOptions requestOptions = 0;
  NSString *priority = [contextInfo objectForKey:LynxImageRequestPriority];
  if ([priority isKindOfClass:[NSString class]]) {
    if ([priority isEqualToString:@"low"]) {
      requestOptions = SDWebImageLowPriority;
    } else if ([priority isEqualToString:@"high"]) {
      requestOptions = SDWebImageHighPriority;
    }
  }

  NSMutableDictionary *context = [NSMutableDictionary dictionary];
  if ([[contextInfo objectForKey:LynxImageFetcherContextKeyDownsampling] boolValue]) {
    CGFloat scale = [UIScreen mainScreen].scale;
    context[SDWebImageContextImageThumbnailPixelSize] =
        [NSValue valueWithCGSize:CGSizeMake(targetSize.width * scale, targetSize.height * scale)];
  }
  if (lynxImage != nil) {
    context[SDWebImageContextAnimatedImageClass] = [SDAnimatedImage class];
  }

  LynxImageRequestToken *token = [LynxImageRequestToken new];
  if (lynxImage != nil) {
    LynxImageRequestBag *bag = RequestBagOf(lynxImage);
    token.bag = bag;
    [bag add:token];
  }
  NSURL *reportedURL = requestUrl.url;
  // A cancelled request never reports: the cancel block runs right before the
  // same `<image>` asks again (a recycled cell, a re-request of the same src),
  // and Lynx would take the late cancellation error for the new request's.
  LynxImageLoadCompletionBlock deliver = ^(UIImage *_Nullable image, NSError *_Nullable error,
                                           NSURL *_Nullable imageURL) {
    [token finish];
    if (token.cancelled) {
      return;
    }
    completed(image, error, reportedURL);
  };

  NSMutableArray *syncProcessors = [NSMutableArray array];
  NSMutableArray *asyncProcessors = [NSMutableArray array];
  for (id<LynxImageProcessor> processor in processors) {
    if ([processor isKindOfClass:[LynxNinePatchImageProcessor class]]) {
      [syncProcessors addObject:processor];
    } else {
      [asyncProcessors addObject:processor];
    }
  }

  SDWebImageCombinedOperation *operation = [[SDWebImageManager sharedManager]
      loadImageWithURL:requestUrl.redirectedURL
               options:requestOptions
               context:context
              progress:nil
             completed:^(UIImage *_Nullable image, NSData *_Nullable data, NSError *_Nullable error,
                         SDImageCacheType cacheType, BOOL finished, NSURL *_Nullable imageURL) {
               if (token.cancelled) {
                 [token finish];
                 return;
               }
               UIImage *syncProcessed = RunNinePatchProcessors(syncProcessors, image);
               if (asyncProcessors.count == 0) {
                 deliver(syncProcessed, error, reportedURL);
                 return;
               }
               dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 UIImage *asyncProcessed = syncProcessed;
                 for (id<LynxImageProcessor> processor in asyncProcessors) {
                   asyncProcessed = [processor processImage:asyncProcessed];
                 }
                 dispatch_async(dispatch_get_main_queue(), ^{
                   deliver(asyncProcessed, error, reportedURL);
                 });
               });
             }];
  token.operation = operation;
  return ^{
    [token cancel];
  };
}

#pragma mark - Switch

@implementation LynxImageRequestCancellation

+ (BOOL)isEnabled {
  @synchronized(self) {
    return gEnabled && gStockLoadNewImage != NULL;
  }
}

+ (void)setEnabled:(BOOL)enabled {
  @synchronized(self) {
    gEnabled = enabled;
  }
}

+ (BOOL)isInstalled {
  @synchronized(self) {
    return gStockLoadNewImage != NULL;
  }
}

+ (void)install {
  @synchronized(self) {
    if (gStockLoadNewImage != NULL) {
      return;
    }
    Class service = NSClassFromString(@"LynxImageService");
    SEL selector = NSSelectorFromString(
        @"loadNewImageFromURL:size:enableGenericFetcher:contextInfo:processors:completed:"
        @"LynxUIImage:");
    Method method = service ? class_getInstanceMethod(service, selector) : NULL;
    if (method == NULL) {
      return;
    }
    gStockLoadNewImage = (LoadNewImageIMP)method_setImplementation(
        method, (IMP)CancellableLoadNewImage);
  }
}

@end
