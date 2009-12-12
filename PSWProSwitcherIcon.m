#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAppContextHostView.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWViewController.h"

static BOOL isUninstalled = NO;

CHDeclareClass(SBApplicationIcon);
CHDeclareClass(PSWProSwitcherIcon);
CHDeclareClass(SpringBoard);
CHDeclareClass(SBIconController);


CHMethod0(void, SBApplicationIcon, launch)
{
	if (!isUninstalled)
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
	CHSuper0(SBApplicationIcon, launch);
}

CHMethod0(void, PSWProSwitcherIcon, launch)
{	
	if (!isUninstalled) {
		PSWViewController *vc = [PSWViewController sharedInstance];
		if (!vc.isAnimating)
			vc.active = !vc.active;
	}
}

CHMethod0(void, PSWProSwitcherIcon, completeUninstall)
{
	if (!isUninstalled) {
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
		isUninstalled = YES;
	}
	CHSuper0(PSWProSwitcherIcon, completeUninstall);
}

static BOOL shouldSuppressIconListScroll;

CHMethod0(void, SpringBoard, _handleMenuButtonEvent)
{
	[[PSWViewController sharedInstance] setActive:NO];
	shouldSuppressIconListScroll = YES;
	CHSuper0(SpringBoard, _handleMenuButtonEvent);
	shouldSuppressIconListScroll = NO;
}

CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldSuppressIconListScroll)
		CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

/* FIXME: use libactivator
CHMethod0(BOOL, SpringBoard, allowMenuDoubleTap)
{
    return YES;
}

CHMethod0(void, SpringBoard, handleMenuDoubleTap)
{
	if (!isUninstalled) {
		PSWViewController *vc = [PSWViewController sharedInstance];
		if (!vc.isAnimating)
			vc.active = !vc.active;
		return;
	}
	
    CHSuper0(SpringBoard, handleMenuDoubleTap);
}
// end fixme */


CHConstructor {
	CHLoadLateClass(SBApplicationIcon);
	CHHook0(SBApplicationIcon, launch);
	CHRegisterClass(PSWProSwitcherIcon, SBApplicationIcon) {
		CHHook0(PSWProSwitcherIcon, launch);
		CHHook0(PSWProSwitcherIcon, completeUninstall);
	}
	CHLoadLateClass(SpringBoard);
	CHHook0(SpringBoard, _handleMenuButtonEvent);
	CHLoadLateClass(SBIconController);
	CHHook2(SBIconController, scrollToIconListAtIndex, animate);
	
	//CHHook0(SpringBoard, allowMenuDoubleTap);
	//CHHook0(SpringBoard, handleMenuDoubleTap);
}