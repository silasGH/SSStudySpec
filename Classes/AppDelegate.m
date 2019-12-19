//
//  AppDelegate.m
//  DGTraffic
//
//  Created by zhangyi on 2017/9/14.
//  Copyright © 2017年 UnionPay. All rights reserved.
//

#import "AppDelegate.h"

#import "DGClient.h"
#import "DGJPush.h"
#import "UPTMainTabBarViewController.h"
#import "UPTMapInstance.h"
#import "UPTGlobalData.h"
#import "UPTUtils.h"
#import "UPTHttpMessage.h"
#import "UPTUserServices.h"
#import "UPDeviceInfo.h"
#import "UPTForceUpdate.h"
#import "UPTGuideViewController.h"
#import <AMapLocationKit/AMapLocationKit.h>
#import "MMJCBrightness.h"
#import "CLLocation+ZLLocation.h"

#import "NSDictionary+SSUnicode.h"
#import "NSArray+SSUnicode.h"
#import "UPTHttpMessage+UPTMine.h"
#import "UPTAdvertisementView.h"
#import "UPTAdvertisementModel.h"

#import <AlipaySDK/AlipaySDK.h>

#import "MMPayManage.h"
#import "DSAlertView.h"

#define kUserDefaults [NSUserDefaults standardUserDefaults]

@interface AppDelegate ()
<
    AMapLocationManagerDelegate
>
//高德地图定位管理
@property (nonatomic, strong)AMapLocationManager *locationManager;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[DGClient sharedDGClient] dgtStart];
#if kIsUsePushNotification
    [[DGJPush sharedDGJPush] appLaunchedWithOptions:launchOptions];
#endif
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.window makeKeyAndVisible];
    
    //通过CFBundleShortVersionString获取程序版本号信息,此处要强制转换成NSString形式
    NSString *versionKey = @"CFBundleShortVersionString";
    //取出沙盒中存储的上次使用软件的版本号
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastVersion = [defaults stringForKey:versionKey];
    //获取当前软件的版本号
    NSString *currentVersion = [NSBundle mainBundle].infoDictionary[versionKey];
    
    if ([currentVersion compare:lastVersion options:NSNumericSearch == NSOrderedDescending]) {
        UPTGuideViewController *guideVC = [[UPTGuideViewController alloc] init];
        self.window.rootViewController = guideVC;
        //存储新版本
        [defaults setObject:currentVersion forKey:versionKey];
        [defaults synchronize];
    } else {
        UPTMainTabBarViewController *myTabBarVC = [[UPTMainTabBarViewController alloc] init];
        self.window.rootViewController = myTabBarVC;
    }
    
    [UPTMapInstance instance];

    if (launchOptions) {
        NSDictionary *remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        NSUserDefaults *remoteNotificationUserDefaults = [NSUserDefaults standardUserDefaults];
        [remoteNotificationUserDefaults setObject:remoteNotification forKey:@"remoteNotification"];
        [remoteNotificationUserDefaults synchronize];
    } else {
        //先加载本地广告数据库,然后再从网络请求新的广告,广告请求成功的时候再从本地数据库删除原存储的广告
        [self getLocalAdvertisingImage];
    }
    //无论本地数据库中是否存在广告图片,都需要重新调用广告接口,判断广告是否更新
    [self getAdvertisingImage];
    
    //开始初始化,初始化成功后再获取用户信息。
    [self appInit];
    
    //在此开启定位功能,防止首页因网络等因素提醒用户是否允许定位弹框提醒不及时问题,问题(可能是否允许还没有弹出,用户已开始了别的操作,使得该提醒不会弹出到的问题)
    //注册高德地图定位管理
    [self configLocationManager];
    
    [MMPAYMANAGER mm_registerApp];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [MMPAYMANAGER mm_handleUrl:url];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [MMPAYMANAGER mm_handleUrl:url];
}

- (BOOL)application:(UIApplication *)application openURL:(nonnull NSURL *)url options:(nonnull NSDictionary<NSString *,id> *)options {
    return [MMPAYMANAGER mm_handleUrl:url];
}

#pragma mark ----- 加载本地广告数据库
//加载本地广告数据库
- (void)getLocalAdvertisingImage {
    NSArray *myArray = [[UPTDBManager sharedInstance] selectAllAdvertisement];
    if (myArray.count > 0) {
        UPTAdvertisementModel *advertisementModel = myArray[arc4random() % myArray.count];
        UIImage *advertisementImage = [UIImage imageWithData:advertisementModel.imgFileNm];
        if (advertisementModel.imgFileNm != nil) {
            UPTAdvertisementView *advertisementView = [[UPTAdvertisementView alloc] initWithFrame:self.window.bounds];
            advertisementView.adView.image = advertisementImage;
//            advertisementView.advertisementModel = advertisementModel;
            advertisementView.adUrl = advertisementModel.adUrl;
            [advertisementView show];
        } else {
            [[UPTDBManager sharedInstance] deleteAdvertisement:advertisementModel.imgFileNm];
        }
    }
}
#pragma mark ----- 初始化广告页面
//初始化广告页面
- (void)getAdvertisingImage {
    UPTHttpMessage *msg = [UPTHttpMessage getAdvertisementPageNo:@"0" adTp:@"0" pageSize:@"5"];
    [[UPTNetEngine shareInstance] sendMessage:msg successHandler:^(NSDictionary *response, NSURLSessionDataTask *task) {
        DSLog(@"%@", response);
        NSDictionary *dataDictionary = response;
        if ([dataDictionary[RespCd] isEqualToString:Succ_Code]) {
            if ([dataDictionary[@"initAdResult"] isKindOfClass:[NSArray class]]) {
                for (NSDictionary *dict in dataDictionary[@"initAdResult"]) {
                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                        [[UPTDBManager sharedInstance] insertAdvertisementImgFileNm:[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/image/ad/%@",ResourceServer,[NSString stringWithFormat:@"%@", dict[@"imgFileNm"]]]]] adSt:[NSString stringWithFormat:@"%@",dict[@"adSt"]] adTp:[NSString stringWithFormat:@"%@",dict[@"adTp"]] adUrl:[NSString stringWithFormat:@"%@",dict[@"adUrl"]] expires:[NSString stringWithFormat:@"%@",dict[@"expires"]]];
                    });
                }
            }
        }
        [[UPTDBManager sharedInstance] deleteAllAdvertisement];
    } errorHandler:^(NSError *error) {
        DSLog(@"");
    }];
}
//当用户在设置中关闭了通知时,程序启动时会调用此函数,我们可以获取用户的设置.
//注册通知
//- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
//    [application registerForRemoteNotifications];
//}
#if kIsUsePushNotification
//用户同意后,会调用此通知,获取系统的deviceToken,把deviceTokken传给服务器保存,此函数会在程序每次启动时调用(前提是用户允许通知)
//获取deviceToken
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    //将deviceToken传给服务器
    [[DGJPush sharedDGJPush] appRegistedForRemoteNotificationsWithDeviceToken:deviceToken];
}
//远程消息推送通知注册失败
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(nonnull NSError *)error {
#ifdef DEBUG
    [DSAlertView alertWithTitle:@"注册APNS失败" content:[error description] cancelBtnTitle:@"ok"];
#endif
}
#endif

//按Home键使App进入后台
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [application setApplicationIconBadgeNumber:0];
    [application cancelAllLocalNotifications];
}
//点击App图标，使App从后台恢复至前台
- (void)applicationWillEnterForeground:(UIApplication *)application {
    [application setApplicationIconBadgeNumber:0];
    [application cancelAllLocalNotifications];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [MMJCBrightness graduallyResumeBrightness];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [MMJCBrightness graduallyResumeBrightness];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSDate *now = [NSDate date];
    NSString *currentTimeString = [formatter stringFromDate:now];
    //从后台呼出,在登录的情况下,并且未实名的情况下请求用户信息
    if ([UPTUserServices isLogin] && [[UPTUserServices getUserInfo].isVerified isEqualToString:@"0"]) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [UPTUserServices queryUserInfoSuccess:nil fail:nil netFail:nil];
        });
    }
    
    if ([self compareNowDateString:currentTimeString lastDateString:[UPTUserServices getUpdateTime]] >= 24) {
        if ([UPTUserServices isLogin] && [[UPTUserServices getUserInfo].isVerified isEqualToString:@"1"]) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [UPTUserServices queryUserInfoSuccess:nil fail:nil netFail:nil];
            });
        }
    }
}
//判定两个时间的相差大小
- (int)compareNowDateString:(NSString *)nowDateString lastDateString:(NSString *)lastDateString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate *nowDate = [dateFormatter dateFromString:nowDateString];
    NSDate *lastDate = [dateFormatter dateFromString:lastDateString];
    NSTimeInterval time = [nowDate timeIntervalSinceDate:lastDate];
    
    int hours = time / 3600;
    return hours;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [MMJCBrightness graduallyResumeBrightness];
}
#pragma mark ----- 注册高德地图定位管理
//注册高德地图定位管理
- (void)configLocationManager {
    self.locationManager = [[AMapLocationManager alloc] init];
    [self.locationManager setDelegate:self];
    [self.locationManager setPausesLocationUpdatesAutomatically:YES];
//    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    //设置允许连续定位逆地理
//    [self.locationManager setLocatingWithReGeocode:YES];
    //设置允许在后台定位
    [self.locationManager setAllowsBackgroundLocationUpdates:NO];
    //开始定位
    [self.locationManager startUpdatingLocation];
}
#pragma mark - AMapLocationManagerDelegate
//高德定位委托方法
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode {
//    location = [location locationEarthFromMars];
    [UPTGlobalData instance].longitude = location.coordinate.longitude;
    [UPTGlobalData instance].latitude = location.coordinate.latitude;
    
    //获取之后就停止更新
//    [self.locationManager stopUpdatingLocation];
}

- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error {
    DLog(@"无法获取位置信息");
}

- (void)appInit {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self appStartInit:^(BOOL isSucc) {
#if kIsUsePushNotification
            [[DGJPush sharedDGJPush] registerForJPush];
#endif
            //程序启动判断用户是否登录，如果登录重新请求新的用户信息
            if ([UPTUserServices isLogin]) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    [UPTUserServices queryUserInfoSuccess:nil fail:nil netFail:nil];
                });
            }
        }];
    });
}
- (void)appStartInit:(void(^)(BOOL isSucc))block{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appCurVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSDictionary *dic = @{@"deviceTp":[UPDeviceInfo modelName],
                          @"deviceId":[UPTUtils deviceUniqueID],
                          @"appVersion":appCurVersion,
                          @"osTp":@"IOS",
                          @"osVersion":[UPDeviceInfo systemVersion],
                          @"isRoot":[UPDeviceInfo isJailbroken]?@"1":@"0",
                          @"resignature":@""};
    //TODO:resignature
    UPTHttpMessage *initMessage = [UPTHttpMessage getAppInit:dic];
    WS(self)
    [[UPTNetEngine shareInstance] sendMessage:initMessage successHandler:^(NSDictionary *response, NSURLSessionDataTask *task) {
        DSLog(@"app初始化--%@", response);
        NSString *responseCd = [response objectForKey:RespCd];
        if ([responseCd isEqualToString:Succ_Code]) {
            NSNumber *zytOpenRate = [NSNumber numberWithInteger:[response[@"zytOpenRate"] integerValue]];
            [[DGClient sharedDGClient] setValue:zytOpenRate forKey:@"zytOpenRate"];
            //升级
            NSString *updateOp = [response objectForKey:RespUpdateOp];
            NSString *updateInfo = [response objectForKey:String_UpdateInfo];
            updateInfo = isNilOrEmptyString(updateInfo)?@"有新版本，请更新":updateInfo;
            NSString *updateUrl = [response objectForKey:String_UpdateURL];
            //0 不升级  1 可选升级   2强制升级            
            if ([updateOp isEqualToString:@"1"]) {
                DSAlertView *alert = [[DSAlertView alloc] initWithTitle:@"提示"
                                                                content:updateInfo
                                                           leftBtnTitle:@"取消"
                                                          rightBtnTitle:@"确定"];
                alert.rightBlock = ^BOOL{
                    //跳转到app store
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:updateUrl]]) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateUrl]];
                    }
                    return NO;
                };
                [alert show];
            }else if([updateOp isEqualToString:@"2"]){
                //强制更新
                [UPTForceUpdate forceUpdate:updateUrl andInfo:updateInfo];
                DLog(@"强制更新");
            }
            
            //VID
//            [UPTUserServices setVid:[response objectForKey:String_Vid]];
            
            [UPTUserServices setUpdateVersion:[response objectForKey:RespUpdateVersion]];
            [UPTUserServices setIosAppStoreUrl:[response objectForKey:RespIosAppStoreUrl]];
            
            //baseUrl 资源服务器地址
            NSString *resourceServer = [response objectForKey:RespResourceServer];
            if (!isNilOrEmptyString(resourceServer)) {
                [UPTUserServices setResourceServer:resourceServer];
            }
            block(YES);
        } else {
            //TODO:初始化失败
            DSLog(@"初始化失败");
        }
    } errorHandler:^(NSError *error) {
        //TODO:初始化失败
        DSLog(@"初始化失败");
        SS(weakSelf)
        [strongSelf appInit];
    }];
}

@end




