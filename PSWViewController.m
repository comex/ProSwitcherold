#import "PSWViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBIconModel.h>
#import "CaptainHook.h"

#define SPRINGBOARD_ACTIVE ![[SBWActiveDisplayStack topApplication] displayIdentifier]

#import "PSWDisplayStacks.h"
#import "PSWResources.h"

CHDeclareClass(SBIconListPageControl);
CHDeclareClass(SBUIController);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBIconModel);
CHDeclareClass(SBIconController);

static PSWViewController *mainController;
static NSInteger suppressIconScatter;

#define PSWPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.collab.proswitcher.plist"]
#define PSWPreferencesChangedNotification "com.collab.proswitcher.preferencechanged"

#define idForKeyWithDefault(dict, key, default)	 ([(dict) objectForKey:(key)]?:(default))
#define floatForKeyWithDefault(dict, key, default)   ({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result floatValue]:(default); })
#define NSIntegerForKeyWithDefault(dict, key, default) (NSInteger)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result integerValue]:(default); })
#define BOOLForKeyWithDefault(dict, key, default)    (BOOL)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result boolValue]:(default); })


@implementation PSWViewController

#define GetPreference(name, type) type ## ForKeyWithDefault(preferences, @#name, name)

// Defaults
#define PSWSnapshotInset		40.0f
#define PSWShowDock             YES
#define PSWAnimateActive        YES
#define PSWDimBackground        YES
#define PSWShowPageControl      YES
#define PSWBackgroundStyle      0
#define PSWSwipeToClose         YES
#define PSWShowApplicationTitle YES
#define PSWShowCloseButton      YES
#define PSWShowEmptyText        YES
#define PSWRoundedCornerRadius  0.0f
#define PSWTapsToActivate       2

+ (PSWViewController *)sharedInstance
{
	if (!mainController)
		mainController = [[PSWViewController alloc] init];
	return mainController;
}

- (void)didFinishDeactivate
{
	[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
	
	if (!SPRINGBOARD_ACTIVE)
	{
		UIWindow *superview = (UIWindow *) [[self view] superview];
		[[self view] removeFromSuperview];
		[superview release];
	}
	else
		[[self view] removeFromSuperview];
	isAnimating = NO;
}

- (void)didFinishActivate
{
	isAnimating = NO;
}

- (BOOL)isActive
{
	return isActive;
}

- (void)setActive:(BOOL)active animated:(BOOL)animated
{
	NSLog(@"setActive:%d current:%d", active, isActive);
	if (active) {
		if (isActive)
			return;
		UIApplication *app = [UIApplication sharedApplication];
		formerStatusBarStyle = [app statusBarStyle];
		[app setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
		isActive = YES;

		snapshotPageView.focusedApplication = focusedApplication;
		UIView *view = [self view];
		
		if (true)//SPRINGBOARD_ACTIVE)
		{
			//UIWindow *rootWindow = [CHSharedInstance(SBUIController) window];
			//[rootWindow addSubview:view];
			UIView *pv = [CHSharedInstance(SBUIController) contentView];
			NSLog(@"The view is %@", pv);
			[pv addSubview:view];
			
			// Find appropriate superview and add as subview
			/*UIView *buttonBar = [CHSharedInstance(SBIconModel) buttonBar];
			UIView *buttonBarParent = [buttonBar superview];
			UIView *superview = [buttonBarParent superview];
			if (GetPreference(PSWShowDock, BOOL))
				[superview insertSubview:view belowSubview:buttonBarParent];
			else
				[superview insertSubview:view aboveSubview:buttonBarParent];*/
		}
		else
		{
			NSLog(@"Window time");
			UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
			[window setWindowLevel:1];
			[window makeKeyAndVisible];
			[window addSubview:view];
		}
		
		if (animated) {
			view.alpha = 0.0f;
			CALayer *layer = [snapshotPageView.scrollView layer];
			[layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didFinishActivate)];
			[layer setTransform:CATransform3DIdentity];
			[view setAlpha:1.0f];
			[UIView commitAnimations];
			isAnimating = YES;
		}
	} else {
		if (!isActive)
			return;
		isActive = NO;
		
		extern int doingStuffMode;
		doingStuffMode = 0;
		
		[focusedApplication release];
		focusedApplication = [snapshotPageView.focusedApplication retain];
		UIView *view = [self view];
		
		SBIconListPageControl *pageControl;
		if (SPRINGBOARD_ACTIVE)
			pageControl = CHIvar(CHSharedInstance(SBIconController), _pageControl, SBIconListPageControl *);
		else
			pageControl = nil;
		
		if (animated) {
			CALayer *layer = [snapshotPageView.scrollView layer];
			[layer setTransform:CATransform3DIdentity];
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didFinishDeactivate)];
			[layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
			[view setAlpha:0.0f];
			[pageControl setAlpha:1.0f];
			[UIView commitAnimations];
			isAnimating = YES;
		} else {
			[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
			[pageControl setAlpha:1.0f];
			[view removeFromSuperview];
		}
	}
}

- (void)setActive:(BOOL)active
{
	[self setActive:active animated:GetPreference(PSWAnimateActive, BOOL)];
}

- (BOOL)isAnimating
{
	return isAnimating;
}

- (id)init
{
	if ((self = [super init])) {
		preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	}	
	return self;
}

- (void)dealloc 
{
	[preferences release];
	[focusedApplication release];
	[snapshotPageView release];
    [super dealloc];
}

- (void)_applyPreferences
{
	self.view.backgroundColor = GetPreference(PSWDimBackground, BOOL) ? [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]:[UIColor clearColor];
	
	if (GetPreference(PSWShowPageControl, BOOL)) {
		SBIconListPageControl *pageControl = CHIvar(CHSharedInstance(SBIconController), _pageControl, SBIconListPageControl *);
		[pageControl setAlpha:0.0f];
	}

	CGRect frame;
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size.width = 320.0f;
	frame.size.height = (GetPreference(PSWShowDock, BOOL) && SPRINGBOARD_ACTIVE) ? 370.0f : 460.0f;
	[snapshotPageView setFrame:frame];
	
	if (GetPreference(PSWBackgroundStyle, NSInteger) == 1)
		[[snapshotPageView layer] setContents:(id)[PSWGetCachedSpringBoardResource(@"ProSwitcherBackground") CGImage]];
	else
		[[snapshotPageView layer] setContents:nil];
	
	snapshotPageView.snapshotInset       = GetPreference(PSWSnapshotInset, float);
	snapshotPageView.allowsSwipeToClose  = GetPreference(PSWSwipeToClose, BOOL);
	snapshotPageView.showsTitles         = GetPreference(PSWShowApplicationTitle, BOOL);
	snapshotPageView.showsCloseButtons   = GetPreference(PSWShowCloseButton, BOOL);
	snapshotPageView.emptyText           = GetPreference(PSWShowEmptyText, BOOL) ? @"No Apps Running":nil;
	snapshotPageView.roundedCornerRadius = GetPreference(PSWRoundedCornerRadius, float);
	snapshotPageView.tapsToActivate      = GetPreference(PSWTapsToActivate, NSInteger);
}

- (void)_reloadPreferences
{
	[preferences release];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	[self _applyPreferences];
}

- (void)loadView 
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 20.0f, 320.0f, 460.0f)];
	
	snapshotPageView = [[PSWSnapshotPageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, (GetPreference(PSWShowDock, BOOL) && SPRINGBOARD_ACTIVE) ? 370.0f : 460.0f) applicationController:[PSWApplicationController sharedInstance]];
	[snapshotPageView setDelegate:self];
	[view addSubview:snapshotPageView];
	
	[self setView:view];
	[self _applyPreferences];
}

- (void)viewDidUnload
{
	[[PSWApplicationController sharedInstance] writeSnapshotsToDisk];
	PSWClearResourceCache();
	[snapshotPageView removeFromSuperview];
	[snapshotPageView release];
	snapshotPageView = nil;
	[super viewDidUnload];
}

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application
{
	suppressIconScatter++;
	[application activate];
	suppressIconScatter--;
}

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application
{
	suppressIconScatter++;
	[application exit];
	suppressIconScatter--;
}

- (void)snapshotPageViewShouldExit:(PSWSnapshotPageView *)snapshotPageView
{
	[self setActive:NO];
}

@end

CHDeclareClass(SBApplication)

CHMethod0(void, SBApplication, activate)
{
	[[PSWViewController sharedInstance] setActive:NO];
	CHSuper0(SBApplication, activate);
}

CHMethod3(void, SBUIController, animateApplicationActivation, SBApplication *, application, animateDefaultImage, BOOL, animateDefaultImage, scatterIcons, BOOL, scatterIcons)
{
	CHSuper3(SBUIController, animateApplicationActivation, application, animateDefaultImage, animateDefaultImage, scatterIcons, scatterIcons && suppressIconScatter == 0);
}

static void PreferenceChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[PSWViewController sharedInstance] _reloadPreferences];
}

CHConstructor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CHLoadLateClass(SBApplication);
	CHLoadLateClass(SBIconController);
	CHHook0(SBApplication, activate);
	CHLoadLateClass(SBIconListPageControl);
	CHLoadLateClass(SBUIController);
	CHHook3(SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBIconModel);
}
