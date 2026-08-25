#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <CoreLocation/CoreLocation.h>
#import <Contacts/Contacts.h>

// 偏好域 + 持久化路径。Preferences bundle 写到 NSUserDefaults，
// 越狱环境下落盘到 /var/mobile/Library/Preferences/<domain>.plist，
// Tweak 进程通过文件直接读，跨进程可靠。
static NSString *const kPLMPrefsPath = @"/var/mobile/Library/Preferences/com.user.mymocktweak.plist";
static NSString *const kPLMNotif     = @"com.user.mymocktweak.settingschanged";

// 直接读文件，无 cache。plist 读 <1ms 可接受；好处是无需 libc++ cxa_guard、
// 设置一改下次取就生效、跨进程稳定。
static NSDictionary *PLMPrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:kPLMPrefsPath] ?: @{};
}

static BOOL PLMEnabled(NSString *key) {
    return [[PLMPrefs() objectForKey:key] boolValue];
}

static NSString *PLMString(NSString *key) {
    id v = PLMPrefs()[key];
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSURL class]])   return [(NSURL *)v path];
    return nil;
}

static double PLMDouble(NSString *key) {
    return [[PLMPrefs() objectForKey:key] doubleValue];
}

#pragma mark - Photo Mock
// 所有 App 通过 PHImageManager 拿到的相册图片，替换为用户指定的本地图片。

%hook PHImageManager
- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset
                              targetSize:(CGSize)targetSize
                             contentMode:(PHImageContentMode)contentMode
                                 options:(PHImageRequestOptions *)options
                           resultHandler:(void (^)(UIImage *_Nullable, NSDictionary *_Nullable))resultHandler {
    if (PLMEnabled(@"enablePhotoMock")) {
        NSString *path = PLMString(@"mockImagePath");
        if (path.length) {
            UIImage *img = [UIImage imageWithContentsOfFile:path];
            if (img) {
                if (resultHandler) resultHandler(img, @{PHImageResultIsInCloudKey: @NO});
                return (PHImageRequestID)arc4random();
            }
        }
    }
    return %orig;
}
%end

#pragma mark - Location Mock
// 所有 App 通过 CLLocationManager.location 读到的位置，替换为用户配置的坐标。
// 仅覆盖同步读路径；持续 startUpdatingLocation 的 delegate 回调暂未接管，
// 需要时可扩展 hook locationManager:didUpdateLocations:。

%hook CLLocationManager
- (CLLocation *)location {
    if (PLMEnabled(@"enableLocationMock")) {
        double lat = PLMDouble(@"mockLatitude");
        double lon = PLMDouble(@"mockLongitude");
        if (lat != 0.0 || lon != 0.0) {
            return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                  altitude:0
                                        horizontalAccuracy:5.0
                                          verticalAccuracy:-1.0
                                                 timestamp:[NSDate date]];
        }
    }
    return %orig;
}
%end

#pragma mark - Contacts Mock
// 所有 App 通过 CNContactStore.unifiedContacts 读到的通讯录，替换为用户指定的 plist。
// plist 结构：NSArray<NSDictionary>，每个 dict 序列化为 CNContact（用法见 README）。

%hook CNContactStore
- (NSArray<CNContact *> *)unifiedContactsMatchingPredicate:(NSPredicate *)predicate
                                              keysToFetch:(NSArray<id<CNKeyDescriptor>> *)keysToFetch
                                                    error:(NSError **)error {
    if (PLMEnabled(@"enableContactsMock")) {
        NSString *path = PLMString(@"mockContactsPath");
        if (path.length) {
            NSArray *arr = [NSArray arrayWithContentsOfFile:path];
            if (arr.count) return arr;
        }
    }
    return %orig;
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[MyMockTweak] injected pid=%d (%@)",
              getpid(),
              NSBundle.mainBundle.bundleIdentifier ?: @"<no-bundle>");
    }
}
