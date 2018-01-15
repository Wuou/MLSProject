//
//  MLSUser.m
//  MinLison
//
//  Created by MinLison on 2017/9/22.
//  Copyright © 2017年 minlison. All rights reserved.
//

#import "MLSUser.h"
#import "Cache.h"
#import "UMLogin.h"
#import "MLSGetPhoneSMSRequest.h"
#import "MLSRefreshTokenRequest.h"
#import "MLSUpdateUserInfoRequest.h"
#import "MLSBindNewPhoneRequest.h"
#import "MLSPopLoginViewController.h"
#import "MLSUserGetNearYardRequest.h"
#import "MLSUserRegisterRequest.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "MLSUpdateUserInfoViewController.h"
#import "MLSFormLoginViewController.h"
#import "MLSUserFindPwdRequest.h"
#import "MLSPwdCondition.h"
#import "MLSPhoneCondition.h"
#import "MLSSMSCondition.h"
#import "MLSUploadImageRequest.h"
#define LNUserLoginUserIdentifier @"LNUserLoginUserIdentifier"
#define LNLoginUserSettingIdentifier(user) [NSString stringWithFormat:@"LNLoginUserSettingIdentifier_%@",user.uid]
#define LNLoginGetSMSIdentifier @"LNLoginGetSMSIdentifier"
#define LNUserLoginFirstIdentifier @"LNUserLoginFirstIdentifier"
#if (DEBUG)
NSInteger const kGetSMSCountTime = 60;
#else
NSInteger const kGetSMSCountTime = 60;
#endif
NSInteger const kGetSMSInitCountTime = 0;

@interface MLSUser ()<YYModel>
@property(nonatomic, assign, readwrite, getter=isLogin) BOOL login;
@property(nonatomic, assign, readwrite, getter=isLogout) BOOL logout;
@property(nonatomic, assign) NSUInteger lastGetSMSTimeInterval;
@property(nonatomic, assign, readwrite) BOOL canRegister;
@property(nonatomic, assign, readwrite) BOOL canLogin;
@property(nonatomic, assign, readwrite, getter=isFirstLogin) BOOL firstLogin;
@property(nonatomic, copy) WGUserLoginSuccessBlock userLoginSuccessBlock;
@property(nonatomic, copy) WGUserFailedBlock userLoginFailedBlock;
@property(nonatomic, assign, getter=isHandleUMMsg) BOOL handleUMMsg;
@property(nonatomic, strong) AMapLocationManager *locationManager;
@property(nonatomic, strong) MLSUserGetNearYardRequest *getNearYardRequest;
@property(nonatomic, assign, getter=isReady) BOOL ready;
@end

@implementation MLSUser
@synthesize lastGetSMSTimeInterval = _lastGetSMSTimeInterval;
+ (instancetype)shareUser
{
        static dispatch_once_t onceToken;
        static MLSUser  *instance = nil;
        dispatch_once(&onceToken,^{
                instance = [[self alloc] init];
                [instance prepare];
        });
        return instance;
}

- (NSUInteger)lastGetSMSTimeInterval
{
        if (!_lastGetSMSTimeInterval) {
#if !(DEBUG)
                _lastGetSMSTimeInterval = [(NSNumber *)[ShareStaticCache objectForKey:LNLoginGetSMSIdentifier] unsignedIntegerValue];
#endif
                if (_lastGetSMSTimeInterval <= 0) {
                        self.lastGetSMSTimeInterval = kGetSMSInitCountTime;
                }
        }
        return _lastGetSMSTimeInterval;
}
- (void)setLastGetSMSTimeInterval:(NSUInteger)lastGetSMSTimeInterval
{
        _lastGetSMSTimeInterval = lastGetSMSTimeInterval;
#if !(DEBUG)
        [ShareStaticCache setObject:@(lastGetSMSTimeInterval) forKey:LNLoginGetSMSIdentifier];
#endif
}
- (BOOL)isLastSMSCountTimeCompletion
{
        return self.lastGetSMSTimeInterval == kGetSMSInitCountTime;
}
- (int)getSMSResidueCountTime
{
        NSUInteger current = (NSUInteger)[[NSDate date] timeIntervalSince1970];
        NSUInteger last = self.lastGetSMSTimeInterval;
        
        if (last == kGetSMSInitCountTime)
        {
                self.lastGetSMSTimeInterval = current;
                return kGetSMSCountTime;
        }
        int residueTime = (int)(kGetSMSCountTime - (current - last));
        if (residueTime <= 0) {
                self.lastGetSMSTimeInterval = kGetSMSInitCountTime;
                return kGetSMSCountTime;
        }
        return (int)MIN(residueTime, kGetSMSCountTime);
}
- (void)prepare
{
        @synchronized(self)
        {
                self.ready = NO;
                MLSUserModel *model = (MLSUserModel *)[ShareStaticCache objectForKey:LNUserLoginUserIdentifier];
                if (model && [model isKindOfClass:[MLSUserModel class]])
                {
                        [self _UpdateWithUserModel:model];
                }
                else
                {
                        [self _UpdateWithUserModel:nil];
                }
                MLSUserSettingModel *settingModel = (MLSUserSettingModel *)[ShareStaticCache objectForKey:LNLoginUserSettingIdentifier(model)];
                if (!settingModel) {
                        settingModel = [[MLSUserSettingModel alloc] init];
                        settingModel.enablePushNotifaction = YES;
                }
                self.userSetting = settingModel;
                
                self.lastGetSMSTimeInterval = kGetSMSInitCountTime;
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
                //        [self requestLocation:nil];
                self.ready = YES;
        }
        
}
- (BOOL)isUserInfoComplete
{
        if (!self.isReady) {
                return NO;
        }
        return self.isLogin && !self.isLogout && !NULLString(self.id_number) && !NULLString(self.name) && !NULLString(self.date) && !NULLString(self.mobile) && !NULLString(self.address) && !NULLString(self.email);
}

- (void)applicationWillTerminate
{
        [self _UpdateWithUserModel:self];
}
- (void)applicationDidReceiveMemoryWarning
{
        //        self.popLoginVC = nil;
}
- (void)applicationDidBecomeActive:(NSNotification *)noti
{
        if ((self.loginType == LNLoginTypeQQ || self.loginType == LNLoginTypeWebchat || self.loginType == LNLoginTypeWeibo))
        {
                if (!self.isHandleUMMsg && self.userLoginFailedBlock)
                {
                        self.userLoginFailedBlock([NSError appErrorWithCode:APP_ERROR_CODE_ERR msg:[NSString app_AuthorizationFailed] remark:nil]);
                }
        }
        self.userLoginFailedBlock = nil;
        self.userLoginSuccessBlock = nil;
}
- (BOOL)isNeedModifyUserInfo
{
        return self.is_new_user && self.loginType == LNLoginTypePhone;
}
- (void)_UpdateWithUserModel:(MLSUserModel *)userModel
{
        
        if ( userModel == nil)
        {
                self.login = NO;
                self.logout = YES;
                [self _JudgeLoginOrRegister];
                [self modelSetWithJSON:[[[MLSUserModel alloc] init] jk_propertyDictionary]];
                [ShareStaticCache removeObjectForKey:LNUserLoginUserIdentifier];
        }
        else
        {
                self.logout = NO;
                self.login = YES;
                
                if ( [userModel isKindOfClass:[MLSUserModel class]] )
                {
                        [self modelSetWithJSON:[userModel modelToJSONObject]];
                        self.old_nickname = userModel.nickname;
                }
                
                [self _JudgeLoginOrRegister];
                
                [ShareStaticCache setObject:self forKey:LNUserLoginUserIdentifier];
                
                [ShareStaticCache setObject:self.userSetting forKey:LNLoginUserSettingIdentifier(userModel)];
                _sms_code = nil;
                self.loginType = LNLoginTypeUnKnown;
        }
}
/// MARK: - Public Method
- (void)popLoginInViewController:(nullable UIViewController *)viewController completion:(nullable void (^)(void))completion dismiss:(nullable void (^)(void))dismiss
{
        [[[MLSPopLoginViewController alloc] initWithType:(WGPopLoginTypeBottomSheet)] presentInViewController:viewController completion:completion dismiss:dismiss];
}
- (void)popLoginIfNeedInViewController:(nullable UIViewController *)viewController completion:(nullable void (^)(void))completion dismiss:(nullable void (^)(void))dismiss
{
        if (self.isLogin && !self.isLogout)
        {
                if (completion) {
                        completion();
                }
                if (dismiss) {
                        dismiss();
                }
        }
        else
        {
                [self popLoginInViewController:viewController completion:completion dismiss:dismiss];
        }
}
- (void)pushOrPresentLoginIfNeed:(BOOL)ifNeed inViewController:(nullable UIViewController *)viewController completion:(nullable void (^)(void))completion dismiss:(nullable void (^)(void))dismiss
{
        MLSFormLoginViewController *vc = [[MLSFormLoginViewController alloc] init];
        if (!ifNeed || !self.isLogin || self.isLogout)
        {
                vc.dismissBlock = dismiss;
                [vc presentOrPushInViewController:viewController?:__KEY_WINDOW__.rootViewController];
        }
        else
        {
                if (completion) {
                        completion();
                }
                if (dismiss) {
                        dismiss();
                }
        }
}
- (void)pushOrPresentUserInfoInViewController:(nullable UIViewController *)viewController completion:(nullable void (^)(void))completion dismiss:(nullable void (^)(void))dismiss
{
        [self popLoginIfNeedInViewController:viewController completion:^{
                
        } dismiss:^{
                if (self.isLogin)
                {
                        [[[MLSUpdateUserInfoViewController alloc] init] presentOrPushInViewController:viewController dismiss:dismiss];
                }
        }];
        
}
- (void)pushOrPresentUserInfoIfNeedInViewController:(nullable UIViewController *)viewController completion:(nullable void (^)(void))completion dismiss:(nullable void (^)(void))dismiss
{
        if (self.userInfoComplete)
        {
                if (completion)
                {
                        completion();
                }
                if (dismiss)
                {
                        dismiss();
                }
        }
        else
        {
                [self pushOrPresentUserInfoInViewController:viewController completion:completion dismiss:dismiss];
        }
}
- (void)loginType:(LNLoginType)type param:(nullable NSDictionary *)params success:(WGUserLoginSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        self.loginType = type;
        if (self.loginType == LNLoginTypePhone)
        {
                [self loginWithPhoneParam:params success:success failed:failed];
        }
        else
        {
                [self loginWithThirdPartyType:self.loginType success:success failed:failed];
        }
}
- (void)logOut:(nullable NSDictionary *)params success:(nullable WGUserStringSuccessBlock)success failed:(nullable WGUserFailedBlock)failed
{
        [self _UpdateWithUserModel:nil];
        if (success) {
                success([NSString aPP_LogoutSuccess]);
        }
}
- (void)loginWithPhoneParam:(NSDictionary *)params success:(WGUserLoginSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSUserPhoneLoginRequest *phoneLoginReq = [MLSUserPhoneLoginRequest requestWithParams:params];
        [self _InsertParamsForRequest:phoneLoginReq];
        
        [phoneLoginReq startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel * _Nonnull data) {
                [self _UpdateWithUserModel:data];
                if (success) {
                        success(data);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed) {
                        failed(error);
                }
        }];
}
- (void)loginWithThirdPartyType:(LNLoginType)type success:(WGUserLoginSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        self.userLoginSuccessBlock = success;
        self.userLoginFailedBlock = failed;
        @weakify(self);
        [UMLogin login:(UMLoginType)type completion:^(BOOL suc, NSError *err, NSDictionary *response) {
                @strongify(self);
                self.handleUMMsg = YES;
                self.loginType = LNLoginTypeUnKnown;
                if (success)
                {
                        NSDictionary *params = @{
                                                 kRequestKeyType : @(type),
                                                 kRequestKeyThird_Party_Id : NOT_NULL_STRING_DEFAULT_EMPTY([response jk_stringForKey:@"usid"]),
                                                 kRequestKeyAvatar :NOT_NULL_STRING_DEFAULT_EMPTY([response jk_stringForKey:@"iconurl"]),
                                                 kRequestKeyNick_Name : NOT_NULL_STRING_DEFAULT_EMPTY([response jk_stringForKey:@"name"])
                                                 };
                        MLSUserThirdLoginRequest *thirdLoginReq = [MLSUserThirdLoginRequest requestWithParams:params];
                        
                        [thirdLoginReq startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel * _Nonnull data) {
                                [self _UpdateWithUserModel:data];
                                if (success) {
                                        success(data);
                                }
                        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                                if (failed) {
                                        failed(error);
                                }
                        }];
                }
                else
                {
                        if (failed)
                        {
                                failed(err);
                        }
                }
        }];
        
}

- (void)getSMSWithParam:(nullable NSDictionary *)params success:(WGUserStringSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSGetPhoneSMSRequest *smsReq = [MLSGetPhoneSMSRequest requestWithParams:params];
        if (![params jk_stringForKey:kRequestKeyMobile])
        {
                [smsReq paramInsert:self.mobile forKey:kRequestKeyMobile];
        }
        
        [smsReq startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof NSString * _Nonnull data) {
                if (success)
                {
                        success([data isKindOfClass:[NSString class]] ? data : request.tipString);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed)
                {
                        failed(error);
                }
        }];
}
- (void)bindPhoneWithParam:(nullable NSDictionary *)params success:(WGUserStringSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSBindNewPhoneRequest *request = [MLSBindNewPhoneRequest requestWithParams:params];
        [self _InsertParamsForRequest:request];
        
        [request startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel *  _Nonnull data) {
                [self _UpdateWithUserModel:data];
                if (success)
                {
                        success(request.tipString);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed)
                {
                        failed(error);
                }
        }];
}

- (void)updateUserInfoWithParam:(nullable NSDictionary *)params success:(WGUserStringSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSUpdateUserInfoRequest *request = [MLSUpdateUserInfoRequest requestWithParams:params];
        
        [self _InsertParamsForRequest:request];
        
        [request startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel * _Nonnull data) {
                [self _UpdateWithUserModel:data];
                if (success)
                {
                        success(request.tipString);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed)
                {
                        failed(error);
                }
        }];
}
- (void)findPwd:(nullable NSDictionary *)params success:(WGUserLoginSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSUserFindPwdRequest *request = [MLSUserFindPwdRequest requestWithParams:params];
        [self _InsertParamsForRequest:request];
        [request startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel * _Nonnull data) {
                [self _UpdateWithUserModel:data];
                if (success)
                {
                        success(self);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed)
                {
                        failed(error);
                }
        }];
}
- (void)registerWithParam:(nullable NSDictionary *)params success:(WGUserLoginSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSUserRegisterRequest *request = [MLSUserRegisterRequest requestWithParams:params];
        [self _InsertParamsForRequest:request];
        [request startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUserModel * _Nonnull data) {
                [self _UpdateWithUserModel:data];
                if (success) {
                        success(self);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed) {
                        failed(error);
                }
        }];
}
- (void)refreshTokenSuccess:(WGUserStringSuccessBlock)success failed:(WGUserFailedBlock)failed
{
        MLSRefreshTokenRequest *request = [MLSRefreshTokenRequest requestWithParams:nil];
        [self _InsertParamsForRequest:request];
        [request startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof NSString * _Nonnull data) {
                if (success)
                {
                        success(data);
                }
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed)
                {
                        failed(error);
                }
        }];
}
- (void)requestLocation:(WGUserLoginSuccessBlock)completion
{
        // 带逆地理（返回坐标和地址信息）。将下面代码中的 YES 改成 NO ，则不会返回地址信息。
        [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
                
                if (error)
                {
                        self.longitude = @"";
                        self.latitude = @"";
                        
                }
                if (location)
                {
                        self.longitude = [NSString stringWithFormat:@"%f",location.coordinate.longitude];
                        self.latitude = [NSString stringWithFormat:@"%f",location.coordinate.latitude];
                }
                if (completion) {
                        completion(self);
                }
        }];
}
- (void)requestNearYard:(nullable WGUserLoginSuccessBlock)completion failed:(WGUserFailedBlock)failed
{
        [self requestLocation:^(MLSUserModel * _Nonnull user) {
                self.getNearYardRequest = [MLSUserGetNearYardRequest requestWithParams:nil];
                [self.getNearYardRequest startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSYardModel * _Nonnull data) {
                        self.currentYardModel = data;
                        if (completion) {
                                completion(self);
                        }
                } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                        if (failed) {
                                failed(error);
                        }
                }];
        }];
}
- (void)uploadUserHeadFileUrl:(NSURL *)imgFileUrl completion:(nullable WGUserLoginSuccessBlock)completion failed:(WGUserFailedBlock)failed
{
        MLSUploadImageRequest *uploadImgRequest = [[MLSUploadImageRequest alloc] initWithImgFileUrl:imgFileUrl];
        @weakify(self);
        [uploadImgRequest startWithSuccess:^(__kindof BaseRequest * _Nonnull request, __kindof MLSUploadImgModel * _Nonnull data) {
                @strongify(self);
                [SDWebImageManager.sharedManager saveImageToCache:[UIImage imageWithContentsOfFile:imgFileUrl.absoluteString] forURL:[NSURL URLWithString:NOT_NULL_STRING_DEFAULT_EMPTY(data.url)]];
                self.img = data.url;
                [self updateUserInfoWithParam:@{
                                                kRequestKeyImg : NOT_NULL_STRING_DEFAULT_EMPTY(data.url)
                                                } success:^(NSString * _Nonnull sms) {
                                                        if (completion) {
                                                                completion(self);
                                                        }
                                                } failed:^(NSError * _Nonnull error) {
                                                        if (failed) {
                                                                failed(error);
                                                        }
                                                }];
        } failed:^(__kindof BaseRequest * _Nonnull request, NSError * _Nonnull error) {
                if (failed) {
                        failed(error);
                }
        }];
}
- (void)_InsertParamsForRequest:(BaseRequest *)request
{
        NSDictionary *dict = (NSDictionary *)[self modelToJSONObject];
        [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if (!NULLObject(obj) && ![request.params objectForKey:key])
                {
                        [request paramInsert:obj forKey:key];
                }
        }];
}

/// MARK: - KVO


- (void)setPhone:(NSString *)mobile
{
        [super setMobile:mobile];
        [self _JudgeLoginOrRegister];
        [self postUserInfoDidChangeNotifaction];
}

- (void)setNickname:(NSString *)nickname
{
        [super setNickname:nickname];
        [self postUserInfoDidChangeNotifaction];
}

- (void)setImg:(NSString *)img
{
        [super setImg:img];
        [self postUserInfoDidChangeNotifaction];
}

- (void)setCountry_code:(NSString *)country_code
{
        [super setCountry_code:country_code];
        [self _JudgeLoginOrRegister];
}
- (void)setCheckAgreement:(BOOL)checkAgreement
{
        if (_checkAgreement != checkAgreement) {
                [self willChangeValueForKey:@keypath(self,checkAgreement)];
                _checkAgreement = checkAgreement;
                [self didChangeValueForKey:@keypath(self,checkAgreement)];
                [self _JudgeLoginOrRegister];
        }
}
- (void)setSms_code:(NSString *)sms_code
{
        if (_sms_code != sms_code) {
                [self willChangeValueForKey:@keypath(self,sms_code)];
                _sms_code = sms_code;
                [self didChangeValueForKey:@keypath(self,sms_code)];
                [self _JudgeLoginOrRegister];
        }
}
- (void)_JudgeLoginOrRegister
{
        if (!self.isReady)
        {
                self.canRegister = NO;
                self.canLogin = NO;
                return;
        }
        self.canRegister = [[MLSPhoneCondition condition] check:self.mobile] && [[MLSSMSCondition condition] check:self.sms_code] && !NULLString(self.country_code) && !self.isLogin && self.isLogout && self.isCheckAgreement;
        self.canLogin = [[MLSPhoneCondition condition] check:self.mobile] && [[MLSPwdCondition condition] check:self.password] && !NULLString(self.country_code) && !self.isLogin && self.isLogout;
}
- (void)postUserInfoDidChangeNotifaction
{
        self.userInfoDidChange = NO;
        self.userInfoDidChange = YES;
        NSNotification *noti = [[NSNotification alloc] initWithName:LNUserInfoDidChangeNotifactionName object:self userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:noti];
}

//===========================================================
// + (BOOL)automaticallyNotifiesObserversForKey:
//
//===========================================================
+ (BOOL)automaticallyNotifiesObserversForKey: (NSString *)theKey
{
        BOOL automatic;
        
        if ([theKey isEqualToString:@keypath(LNUserManager,login)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,logout)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,canRegister)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,canLogin)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,userInfoDidChange)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,password)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,mobile)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,repeat_password)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,sms_code)]) {
                automatic = NO;
        } else if ([theKey isEqualToString:@keypath(LNUserManager,checkAgreement)]) {
                automatic = NO;
        } else {
                automatic = [super automaticallyNotifiesObserversForKey:theKey];
        }
        return automatic;
}

- (void)setPassword:(NSString *)password
{
        if (_password != password) {
                [self willChangeValueForKey:@keypath(self,password)];
                _password = password;
                [self _JudgeLoginOrRegister];
                [self didChangeValueForKey:@keypath(self,password)];
        }
}
- (void)setRepeat_password:(NSString *)repeat_password
{
        if (_repeat_password != repeat_password) {
                [self willChangeValueForKey:@keypath(self,repeat_password)];
                _repeat_password = repeat_password;
                [self _JudgeLoginOrRegister];
                [self didChangeValueForKey:@keypath(self,repeat_password)];
        }
}
- (void)setUserInfoDidChange:(BOOL)userInfoDidChange
{
        [self willChangeValueForKey:@keypath(self,userInfoDidChange)];
        _userInfoDidChange = userInfoDidChange;
        [self didChangeValueForKey:@keypath(self,userInfoDidChange)];
}
- (void)setLogin:(BOOL)flag
{
        if (_login != flag) {
                [self willChangeValueForKey:@keypath(self,login)];
                _login = flag;
                [self postUserInfoDidChangeNotifaction];
                [self didChangeValueForKey:@keypath(self,login)];
        }
}
- (void)setLogout:(BOOL)flag
{
        if (_logout != flag) {
                [self willChangeValueForKey:@keypath(self,logout)];
                _logout = flag;
                [self postUserInfoDidChangeNotifaction];
                [self didChangeValueForKey:@keypath(self,logout)];
        }
}
- (void)setCanRegister:(BOOL)flag
{
        if (_canRegister != flag) {
                [self willChangeValueForKey:@keypath(self,canRegister)];
                _canRegister = flag;
                [self didChangeValueForKey:@keypath(self,canRegister)];
        }
}
- (void)setCanLogin:(BOOL)flag
{
        if (_canLogin != flag) {
                [self willChangeValueForKey:@keypath(self,canLogin)];
                _canLogin = flag;
                [self didChangeValueForKey:@keypath(self,canLogin)];
        }
}
+ (NSDictionary<NSString *,id> *)modelCustomPropertyMapper
{
        NSMutableDictionary *dictM = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                     @keypath(LNUserManager,sms_code) : @[@"code"]
                                                                                      }];
        if ([super respondsToSelector:@selector(modelCustomPropertyMapper)])
        {
                NSDictionary *dict = [super modelCustomPropertyMapper];
                if (dict)
                {
                        [dictM addEntriesFromDictionary:dict];
                }
                
        }
        
        return dictM;
}
+ (NSArray<NSString *> *)modelPropertyBlacklist
{
        MLSUser *user = nil;
        return @[@keypath(user,old_nickname),
                  @keypath(user,login),
                  @keypath(user,logout),
                  @keypath(user,canLogin),
                  @keypath(user,canRegister),
                  @keypath(user,lastGetSMSTimeInterval),
                  @keypath(user,loginType),
                  @keypath(user,needModifyUserInfo),
                  @keypath(user,userLoginFailedBlock),
                  @keypath(user,userLoginSuccessBlock),
                  @keypath(user,userSetting),
                  @keypath(user,currentYardModel),
                  @keypath(user,repeat_password),
                  @keypath(user,handleUMMsg),
                  @keypath(user,userInfoComplete),
                  @keypath(user,userInfoDidChange),
                  @keypath(user,firstLogin),
                  @keypath(user,checkAgreement),
                  @keypath(user,getNearYardRequest),
                  @keypath(user,locationManager),
                  @keypath(user,ready),
                  //                  @keypath(user,popLoginVC),
                  ];
}

+ (NSDictionary *)jk_codableProperties
{
        NSDictionary *dict = [super jk_codableProperties];
        NSMutableDictionary *dictM = [NSMutableDictionary dictionaryWithDictionary:dict];
        [dictM removeObjectsForKeys:[self modelPropertyBlacklist]];
        return dictM;
}

- (AMapLocationManager *)locationManager
{
        if (!_locationManager)
        {
                _locationManager = [[AMapLocationManager alloc] init];
                // 带逆地理信息的一次定位（返回坐标和地址信息）
                [_locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
                //   定位超时时间，最低2s，此处设置为2s
                _locationManager.locationTimeout = 2;
                //   逆地理请求超时时间，最低2s，此处设置为2s
                _locationManager.reGeocodeTimeout = 2;
        }
        return _locationManager;
}
@end
NSString *const LNUserInfoDidChangeNotifactionName = @"LNUserInfoDidChangeNotifactionName";
