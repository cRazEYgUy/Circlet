#import "CRPrefs.h"

void circletSidesRefresh(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CRReloadPreferences" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CLSmartDisable" object:nil];

	UIStatusBar *statusBar = (UIStatusBar *)[[UIApplication sharedApplication] statusBar];
	UIView *fakeStatusBar;

	if (MODERN_IOS) {
		fakeStatusBar = [statusBar snapshotViewAfterScreenUpdates:YES];
	}

	else {
		UIGraphicsBeginImageContextWithOptions(statusBar.frame.size, NO, [UIScreen mainScreen].scale);
		CGContextRef context = UIGraphicsGetCurrentContext();
		[statusBar.layer renderInContext:context];
		UIImage *statusBarImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		fakeStatusBar = [[UIImageView alloc] initWithImage:statusBarImage];
	}

	CGRect upwards = statusBar.frame;
	upwards.origin.y -= upwards.size.height;

	[statusBar.superview addSubview:fakeStatusBar];
	statusBar.frame = upwards;

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CRRefreshStatusBar" object:nil];

	CGFloat shrinkAmount = 5.0;
	[UIView animateWithDuration:0.6 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void){
		CRLOG(@"Animating out...");
		
		CGRect shrinkFrame = fakeStatusBar.frame;
		shrinkFrame.origin.x += shrinkAmount;
		shrinkFrame.origin.y += shrinkAmount;
		shrinkFrame.size.width -= shrinkAmount;
		shrinkFrame.size.height -= shrinkAmount;
		fakeStatusBar.frame = shrinkFrame;
		fakeStatusBar.alpha = 0.0;
		
		CGRect downwards = statusBar.frame;
		downwards.origin.y += downwards.size.height;
		statusBar.frame = downwards;
	} completion: ^(BOOL finished) {
		[fakeStatusBar removeFromSuperview];
	}];
}

void circletCenterRefresh(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CRReloadPreferences" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CLSmartDisable" object:nil];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CRRefreshTime" object:nil];
}

@implementation CRPrefsListController

- (void)loadView {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &circletSidesRefresh, CFSTR("com.insanj.circlet/Sides"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &circletCenterRefresh, CFSTR("com.insanj.circlet/Center"), NULL, 0);
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(smartDisable) name:@"CLSmartDisable" object:nil];

	[super loadView];

	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = CRTINTCOLOR;
	[UISegmentedControl appearanceWhenContainedIn:self.class, nil].tintColor = CRTINTCOLOR;
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareTapped:)] autorelease];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:(IPAD ? @"CRBPrefs" : @"CRPrefs") target:self] retain];
	}

	return _specifiers;
}

- (void)viewDidDisappear:(BOOL)animated {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pullHeaderPin) object:nil];
	[super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
	if (MODERN_IOS) {
		self.view.tintColor = CRTINTCOLOR;
	    self.navigationController.navigationBar.tintColor = CRTINTCOLOR;
	}

	[self smartDisable];
	[self pullHeaderPin];

	[super viewWillAppear:animated];
}

- (void)pullHeaderPin {
	CRLOG(@"Pulling header pin...");
	NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:[NSDate date]];
	CGFloat hour = [components hour];
	CGFloat minute = [components minute] / 60.0;
	CGFloat combined = (fmod(hour + minute, 12.0) + 1.0) / 12.0;

	CRLOG(@"Percentage full: %f", combined);

	if (!self.navigationItem.titleView) {
		// Randomly pick radial, fill, concentric or their inverses
		NSInteger style = arc4random_uniform(1) + arc4random_uniform(3);

		self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage circletWithColor:CRTINTCOLOR radius:13.0 percentage:combined style:style]];
		self.navigationItem.titleView.tag = style;
	}

	else {
		UIImageView *titleView = (UIImageView *) self.navigationItem.titleView;
		titleView.image = [UIImage circletWithColor:CRTINTCOLOR radius:13.0 percentage:combined style:titleView.tag];
	}
	
	[self performSelector:@selector(pullHeaderPin) withObject:nil afterDelay:(60.0 - [components second])];
}

- (void)smartDisable {
	CRLOG(@"Smart disabling...");	
	PSSpecifier *signalAdjustmentsSpecifier = [self specifierForID:@"SignalAdjustments"];
	PSSpecifier *carrierTextSpecifier = [self specifierForID:@"CarrierText"];
	PSSpecifier *wifiAdjustmentsSpecifier = [self specifierForID:@"WifiAdjustments"];
	PSSpecifier *dataAdjustmentsSpecifier = [self specifierForID:@"DataAdjustments"];
	PSSpecifier *timeAdjustmentsSpecifier = [self specifierForID:@"TimeAdjustments"];
	PSSpecifier *batteryAdjustmentsSpecifier = [self specifierForID:@"BatteryAdjustments"];

	CRPrefsManager *manager = [CRPrefsManager sharedManager];

	NSNumber *signalValue = [manager numberForKey:@"signalEnabled"];
	BOOL signalEnabled = !signalValue || [signalValue boolValue];
	[signalAdjustmentsSpecifier setProperty:@(signalEnabled) forKey:@"enabled"];
	[self reloadSpecifier:signalAdjustmentsSpecifier];

	[carrierTextSpecifier setProperty:@([manager boolForKey:@"carrierEnabled"]) forKey:@"enabled"];
	[self reloadSpecifier:carrierTextSpecifier];

	[wifiAdjustmentsSpecifier setProperty:@([manager boolForKey:@"wifiEnabled"]) forKey:@"enabled"];
	[self reloadSpecifier:wifiAdjustmentsSpecifier];
	
	[dataAdjustmentsSpecifier setProperty:@([manager boolForKey:@"dataEnabled"]) forKey:@"enabled"];
	[self reloadSpecifier:dataAdjustmentsSpecifier];

	[timeAdjustmentsSpecifier setProperty:@([manager boolForKey:@"timeEnabled"]) forKey:@"enabled"];
	[self reloadSpecifier:timeAdjustmentsSpecifier];

	[batteryAdjustmentsSpecifier setProperty:@([manager boolForKey:@"batteryEnabled"]) forKey:@"enabled"];
	[self reloadSpecifier:batteryAdjustmentsSpecifier];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	if (MODERN_IOS) {
		self.view.tintColor = nil;
	    self.navigationController.navigationBar.tintColor = nil;
	}
}

- (void)tableView:(id)arg1 didSelectRowAtIndexPath:(id)arg2 {
 	[super tableView:arg1 didSelectRowAtIndexPath:arg2];
	[arg1 deselectRowAtIndexPath:arg2 animated:YES];
}

- (void)shareTapped:(UIBarButtonItem *)sender {
	NSString *text = @"Life has never been simpler than with #Circlet by @insanj.";
	NSURL *url = [NSURL URLWithString:@"http://insanj.com/circlet"];

	if (%c(UIActivityViewController)) {
		UIActivityViewController *viewController = [[[%c(UIActivityViewController) alloc] initWithActivityItems:[NSArray arrayWithObjects:text, url, nil] applicationActivities:nil] autorelease];
		[self.navigationController presentViewController:viewController animated:YES completion:NULL];
	}

	else if (%c(TWTweetComposeViewController) && [TWTweetComposeViewController canSendTweet]) {
		TWTweetComposeViewController *viewController = [[[TWTweetComposeViewController alloc] init] autorelease];
		viewController.initialText = text;
		[viewController addURL:url];
		[self.navigationController presentViewController:viewController animated:YES completion:NULL];
	}

	else {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://twitter.com/intent/tweet?text=%@%%20%@", URL_ENCODE(text), URL_ENCODE(url.absoluteString)]]];
	}
}

- (void)twitter { 
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetbot:///user_profile/insanj"]];
	}

	else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitterrific:///profile?screen_name=insanj"]];
	}

	else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetings:///user?screen_name=insanj"]];
	}

	else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://user?screen_name=insanj"]];
	}

	else {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://mobile.twitter.com/insanj"]];
	}
}

- (void)github {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/insanj/circlet"]];
}

- (void)website {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://insanj.com/circlet"]];
}

- (void)dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

// iPad seems to obey all laws. -smartDisable doesn't work here, too, for some reason.
- (BOOL)canBeShownFromSuspendedState {
	if (IPAD) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CLGTFO" object:nil userInfo:@{ @"sender" : NSStringFromClass([UIApplication sharedApplication].class)} ];
	}

	return NO; 
}

@end
