// Private macOS APIs used by Lumio. Everything undocumented lives here so that
// a breaking macOS update has exactly one place to look.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - CGVirtualDisplay (CoreGraphics / SkyLight)
// A virtual display lives exactly as long as its CGVirtualDisplay object.

@interface CGVirtualDisplayMode : NSObject
@property (readonly, nonatomic) CGFloat refreshRate;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(CGFloat)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
/// 1 = every mode also gets a 2× (HiDPI) variant if it fits in maxPixels.
@property (nonatomic) unsigned int hiDPI;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property (retain, nonatomic) NSString *name;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int serialNum;
@property (copy, nonatomic, nullable) void (^terminationHandler)(id, id);
- (void)setDispatchQueue:(dispatch_queue_t)queue;
@end

@interface CGVirtualDisplay : NSObject
@property (readonly, nonatomic) CGDirectDisplayID displayID;
- (nullable instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

#pragma mark - IOAVService (IOKit, Apple Silicon DDC/CI)

typedef CFTypeRef IOAVServiceRef;
extern IOAVServiceRef _Nullable IOAVServiceCreateWithService(CFAllocatorRef _Nullable allocator, io_service_t service) CF_RETURNS_RETAINED;
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void *outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *inputBuffer, uint32_t inputBufferSize);

NS_ASSUME_NONNULL_END
