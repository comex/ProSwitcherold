//
//  PSWRandomStuff.m
//  ProSwitcher
//
//  Created by Nicholas Allegra on 12/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSWRandomStuff.h"
#import "PSWDisplayStacks.h"
#import "PSWViewController.h"
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAppContextHostView.h>
#import "CaptainHook.h"

#define SPRINGBOARD_ACTIVE ![[SBWActiveDisplayStack topApplication] displayIdentifier]

PSWRandomDude *dude;
double doingStuffTime = 0;
int doingStuffMode = 0;


CHDeclareClass(SBUIController);

@implementation PSWRandomDude
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	SBAppContextHostView *chv = (SBAppContextHostView *) [[SBWActiveDisplayStack topApplication] contextHostView];
	[chv setHostingEnabled:NO];			
	[chv removeFromSuperview];			
	chv.hidden = YES;
	doingStuffMode = 0;
}
@end

CHMethod0(BOOL, SBUIController, clickedMenuButton)
{
	NSLog(@"doingStuffMode = %d", doingStuffMode);
	if(SPRINGBOARD_ACTIVE) {
		return CHSuper0(SBUIController, clickedMenuButton);
	}
	double now = [NSDate timeIntervalSinceReferenceDate];
	if(doingStuffMode == 1) {
		if(now - doingStuffTime > 1.5) {
			SBAppContextHostView *chv = (SBAppContextHostView *) [[SBWActiveDisplayStack topApplication] contextHostView];
			//chv.userInteractionEnabled = YES;
			/*CGAffineTransform transform = CGAffineTransformIdentity;
			[UIView beginAnimations:nil context:NULL]; 
			[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
			[UIView setAnimationDelegate:dude];


			chv.transform = transform;
			[UIView commitAnimations];
			
			doingStuffTime = 0;
			doingStuffMode = 2;
			return true;//*/
			[[PSWViewController sharedInstance] setActive:NO];
			doingStuffTime = 0;
			doingStuffMode = 0;			
			return CHSuper0(SBUIController, clickedMenuButton);
		} else {
			return true;
		}
	} else if(doingStuffMode == 2) {
		return true;
	} else {
		NSLog(@"Doing stuff time!");
		doingStuffTime = now;
		
		SBAppContextHostView *chv = (SBAppContextHostView *) [[SBWActiveDisplayStack topApplication] contextHostView];
		[PSWSnapshotView setHostView:chv];
		//SBUIController *uic = (SBUIController *) [NSClassFromString(@"SBUIController") sharedInstance];
		chv.userInteractionEnabled = NO;
		chv.hidden = NO;
		NSLog(@":<");
		[chv setHostingEnabled:YES];
		chv.transform = CGAffineTransformIdentity;		
		[self restoreIconList:NO];
		NSLog(@"Setting");
		doingStuffMode = 1;
		[[PSWViewController sharedInstance] setActive:YES animated:NO];
		return true;
	}
}

CHConstructor
{
	dude = [[PSWRandomDude alloc] init];
	CHLoadLateClass(SBUIController);
	CHHook0(SBUIController, clickedMenuButton);
}
