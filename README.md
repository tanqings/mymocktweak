# MyMockTweak

一个通用的 iOS Mock Tweak，在越狱设备上 hook 系统框架的公开 API，让设备所有者管理**其他 App** 通过 `PHImageManager` / `CLLocationManager` / `CNContactStore` 读到的数据。

## 边界声明（先说清楚）

- 这是**全新独立工程**，不复刻、不引用任何第三方商业 App 的代码或逻辑。
- **不包含**任何鉴权绕过、付费解锁、Pro 激活相关代码。
- 所有 hook 的都是 Apple 公开系统框架的公开 API，行为完全由设备所有者在设置面板控制。
- 默认所有 Mock 开关为 `false`（关），不配数据就不会改任何东西。

## 工程结构

```
MyMockTweak/
├── Makefile                          主工程，编 Tweak + 子工程 Preferences
├── MyMockTweak.plist                 Tweak filter，注入到所有 UIKit App
├── control                           deb 包元数据
├── Tweak.x                           核心 hook：相册/位置/通讯录三模块
├── Preferences/
│   ├── Makefile                      Preferences bundle 子工程
│   ├── PRMPrefsListController.{h,m}  设置面板入口控制器
│   ├── MyMockTweak.plist             PreferenceLoader 入口（让设置 App 显示条目）
│   └── MyMockTweakPrefs.bundle/
│       ├── Info.plist                bundle metadata
│       └── Root.plist                设置项 layout（开关 + 文本输入）
└── sample/
    └── contacts.sample.plist         假通讯录示例
```

## 前置条件

1. **Theos**：`git clone --recursive https://github.com/theos/theos.git ~/theos`，设 `THEOS=~/theos`。
2. **iOS SDK**：放一份 iPhoneOS.sdk 到 `$THEOS/sdks/`（任意可用的 SDK 都行，target 写对应版本号）。
3. **越狱设备**：dopamine / palera1n / roothide 任一，已装 **MobileSubstitute** 和 **PreferenceLoader**（一般随 Sileo 自动装）。

如果你的 SDK 不是 16.5 或部署目标不是 14.0，改两个 Makefile 里的 `TARGET := iphone:clang:<SDK>:<DEPLOYMENT>` 行。

## 构建

```bash
cd MyMockTweak
make package            # 产物在 packages/com.user.mymocktweak_0.1.0_*.deb
```

ARM64e 设备（A12+）和 ARM64 设备都会同时编（`ARCHS = arm64 arm64e`）。

## 安装

任选一种：

```bash
# 方法 1：Theos 直接 install（需设备 SSH 配置在 ~/.ssh/config 或 THEOS_DEVICE_IP）
make install THEOS_DEVICE_IP=<设备IP> THEOS_DEVICE_PORT=22

# 方法 2：scp + dpkg
scp packages/com.user.mymocktweak_0.1.0_*.deb root@<设备IP>:/tmp/
ssh root@<设备IP> "dpkg -i /tmp/com.user.mymocktweak_*.deb && killall -9 SpringBoard"

# 方法 3：用 Filza / Sileo 直接打开 deb 文件安装
```

装完 respring 后，**系统设置**里最下面会出现 **MyMockTweak** 入口（如果没出现，确认装了 PreferenceLoader）。

## 配置

进入「设置 → MyMockTweak」，三个分组：

### 相册 Mock
- **启用**：开关
- **假图路径**：本地图片绝对路径，如 `/var/mobile/mock.png`。把图片放进去：
  ```bash
  scp mock.png root@<设备IP>:/var/mobile/mock.png
  ```

### 位置 Mock
- **启用**：开关
- **纬度 / 经度**：十进制数字（负号表示南纬/西经）

### 通讯录 Mock
- **启用**：开关
- **plist 路径**：联系人列表文件，格式见 `sample/contacts.sample.plist`。装到设备：
  ```bash
  scp sample/contacts.sample.plist root@<设备IP>:/var/mobile/contacts.plist
  ```

修改任何项都会发 `com.user.mymocktweak.settingschanged` 通知，Tweak 进程内 cache 自动刷新，**无需 respring** 即时生效（对正在调用的方法立即生效；已运行的 App 下次取数据时生效）。

## 测试方法

| Mock | 怎么验证 |
|------|---------|
| 相册 | 系统自带「照片」App 或任意第三方相册浏览 App，相册里所有缩略图都变成你指定的假图 |
| 位置 | 系统自带「指南针」或「地图」，或任意取位置的 App，读到的坐标变成你配置的值 |
| 通讯录 | 系统自带「通讯录」或微信等读取通讯录的 App，列表变成你 plist 指定的联系人 |

如果没生效：
1. 确认开关为开、路径不为空、文件确实存在且可读（`ls -l /var/mobile/...`）。
2. 看 Console：注入时 Tweak 会打 `[MyMockTweak] injected pid=...` 日志，目标 App 进程出现该日志说明注入成功。
3. 看 Tweak 是否被装到对应 App：filter 是 `com.apple.UIKit`，所有 UIKit App 都会注入。

## 已知限制（功能边界）

- **位置 Mock** 只覆盖 `- [CLLocationManager location]` 同步读。`startUpdatingLocation` 后通过 delegate `locationManager:didUpdateLocations:` 异步回调的路径**未 hook**。需要扩展时在 `Tweak.x` 里加 `CLLocationManager` 的 `startUpdatingLocation` hook + 在原回调后注入假 `CLLocation`。
- **相册 Mock** 只覆盖 `PHImageManager` 主路径。`PHAsset` 的图像数据、`PHFetchResult` 列表本身**未改**，所以列表里 asset 数量不变，只是每个 asset 取出来变成假图。如果要让"列表里也只剩一张图"，需要 hook `PHFetchResult`。
- **通讯录 Mock** 只覆盖 `unifiedContactsMatchingPredicate:keysToFetch:error:`。`enumerateContactsWithFetchRequest:error:usingBlock:` 等其他读取路径未覆盖。
- 没做**按 App 黑白名单**：所有 UIKit App 一视同仁。要按 bundle ID 区分，可在 `Tweak.x` 各 hook 开头加 `[NSBundle.mainBundle.bundleIdentifier isEqualToString:@"..."]` 判断。
- 没做**偏好面板密码保护**：设备解锁的人都能改配置。

## 可扩展点

按需在 `Tweak.x` 里加：

```objc
// 1. 按进程过滤
static BOOL PLMShouldApply(void) {
    NSString *bid = NSBundle.mainBundle.bundleIdentifier;
    if ([bid hasPrefix:@"com.apple."] && !PLMEnabled(@"applyToSystemApps")) return NO;
    return YES;
}

// 2. hook 异步定位回调
%hook CLLocationManager
- (void)startUpdatingLocation {
    %orig;
    if (PLMEnabled(@"enableLocationMock")) {
        // 用 dispatch_after 模拟持续回调假坐标
    }
}
%end

// 3. 让相册列表只剩 1 张
%hook PHFetchResult
- (NSUInteger)count { return PLMEnabled(@"enablePhotoMock") ? 1 : %orig; }
- (id)objectAtIndex:(NSUInteger)idx { return /* 你的假 asset */; }
%end
```

## 不做的事

- 不会绕过任何 App 的内购、订阅、Pro 鉴权逻辑。
- 不会 hook 任何第三方商业 App 的私有方法或混淆类。
- 不会读取或上传用户数据到任何服务器。

这是个**设备所有者管理自己设备显示什么给 App** 的工具，跟破解场景不沾边。
