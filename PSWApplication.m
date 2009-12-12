#import "PSWApplication.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconModel.h>
#import "SpringBoard+Backgrounder.h"

#import "PSWDisplayStacks.h"

CHDeclareClass(SBApplicationController);
CHDeclareClass(SBApplicationIcon);
CHDeclareClass(SBIconModel);

CHConstructor {
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBApplicationIcon);
	CHLoadLateClass(SBIconModel);
}

static NSString *ignoredRelaunchDisplayIdentifier;

@implementation PSWApplication

@synthesize displayIdentifier = _displayIdentifier;
@synthesize application = _application;
@synthesize delegate = _delegate;

+ (NSString *)snapshotPath
{
	return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/"];
}

+ (void)clearSnapshotCache
{
	NSString *snapshotPath = [self snapshotPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for (NSString *path in [fileManager contentsOfDirectoryAtPath:snapshotPath error:NULL])
		if ([snapshotPath hasPrefix:@"ProSwitcher-"] && [snapshotPath hasSuffix:@".cache"])
			[fileManager removeItemAtPath:[snapshotPath stringByAppendingPathComponent:snapshotPath] error:NULL];
}

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier
{
	if ((self = [super init])) {
		_application = [[CHSharedInstance(SBApplicationController) applicationWithDisplayIdentifier:displayIdentifier] retain];
		_displayIdentifier = [displayIdentifier copy];
	}
	return self;
}

- (id)initWithSBApplication:(SBApplication *)application
{
	if ((self = [super init])) {
		_application = [application retain];
		_displayIdentifier = [[application displayIdentifier] copy];
	}
	return self;
}

- (void)dealloc
{
	[_displayIdentifier release];
	CGImageRelease(_snapshotImage);
	[_snapshotData release];
#ifdef USE_IOSURFACE
	if (_surface) {
		CFRelease(_surface);
		_surface = NULL;
	}
#endif
	if (_snapshotFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
		[_snapshotFilePath release];
	}		
	[_application release];
	[super dealloc];
}

- (NSString *)displayName
{
	return [_application displayName];
}

- (CGImageRef)snapshot
{
	if (!_snapshotImage) {
		_snapshotImage = [[_application defaultImage:NULL] CGImage];
		CGImageRetain(_snapshotImage);
	}
	return _snapshotImage;
}

- (void)setSnapshot:(CGImageRef)snapshot
{
	if (_snapshotImage != snapshot) {
		CGImageRelease(_snapshotImage);
		[_snapshotData release];
		if (_snapshotFilePath) {
			[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
			[_snapshotFilePath release];
			_snapshotFilePath = nil;
		}
		if (snapshot) {
			size_t width = CGImageGetWidth(snapshot);
			size_t height = CGImageGetHeight(snapshot);
			void *buffer = calloc(4, width * height);
			_snapshotData = [[NSMutableData alloc] initWithBytesNoCopy:buffer length:(4 * width * height) freeWhenDone:YES];
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef context = CGBitmapContextCreate(buffer, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CGColorSpaceRelease(colorSpace);
			CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), snapshot);
			_snapshotImage = CGBitmapContextCreateImage(context);
			CGContextRelease(context);
		} else {
			_snapshotImage = NULL;
			_snapshotData = nil;
		}
#ifdef USE_IOSURFACE
		if (_surface) {
			CFRelease(_surface);
			_surface = NULL;
		}
#endif
		if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
			[_delegate applicationSnapshotDidChange:self];
	}
}

/*- (void)loadSnapshotFromBuffer:(void *)buffer width:(NSUInteger)width height:(NSUInteger)height stride:(NSUInteger)stride
{
	CGImageRelease(_snapshotImage);
	if (_snapshotFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
		[_snapshotFilePath release];
		_snapshotFilePath = nil;
	}
#ifdef USE_IOSURFACE
	if (_surface) {
		CFRelease(_surface);
		_surface = NULL;
	}
#endif
	[_snapshotData release];
	_snapshotData = [[NSData alloc] initWithBytes:buffer length:(height * stride)];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate((void *)[_snapshotData bytes], width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	_snapshotImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
		[_delegate applicationSnapshotDidChange:self];
}*/

#ifdef USE_IOSURFACE
- (void)loadSnapshotFromSurface:(IOSurfaceRef)surface
{
	if (surface != _surface) {
		CGImageRelease(_snapshotImage);
		[_snapshotData release];
		if (_snapshotFilePath) {
			[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
			[_snapshotFilePath release];
			_snapshotFilePath = nil;
		}
		if (_surface)
			CFRelease(_surface);
		if (surface) {
			_surface = (IOSurfaceRef)CFRetain(surface);
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef context = CGBitmapContextCreate(IOSurfaceGetBaseAddress(surface), IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface), 8, IOSurfaceGetBytesPerRow(surface), colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CGColorSpaceRelease(colorSpace);
			_snapshotImage = CGBitmapContextCreateImage(context);
			CGContextRelease(context);
		} else {
			_snapshotImage = NULL;
			_surface = NULL;
		}
		_snapshotData = nil;
		if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
			[_delegate applicationSnapshotDidChange:self];
	}
}
#endif

- (SBApplicationIcon *)springBoardIcon
{
	return [CHSharedInstance(SBIconModel) iconForDisplayIdentifier:_displayIdentifier];
}

- (void)exit
{
	if ([_displayIdentifier isEqualToString:@"com.apple.mobilephone"] || [_displayIdentifier isEqualToString:@"com.apple.mobilemail"] || [_displayIdentifier isEqualToString:@"com.apple.mobilesafari"] || [_displayIdentifier hasPrefix:@"com.apple.mobileipod"] || [_displayIdentifier isEqualToString:@"com.googlecode.mobileterminal"]) {
		[ignoredRelaunchDisplayIdentifier release];
		ignoredRelaunchDisplayIdentifier = [_displayIdentifier retain];
		[_application kill];
	} else {
		UIApplication *sharedApp = [UIApplication sharedApplication];
		if ([sharedApp respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
			[sharedApp setBackgroundingEnabled:NO forDisplayIdentifier:_displayIdentifier];
		if ([SBWActiveDisplayStack containsDisplay:_application]) {
			[_application setDeactivationSetting:0x2 flag:YES]; // animate
			[SBWActiveDisplayStack popDisplay:_application];
		} else {
			[_application setDeactivationSetting:0x2 flag:NO]; // don't animate
		}
		// Deactivate the application
		[_application setActivationSetting:0x2 flag:NO]; // don't animate
		[SBWSuspendingDisplayStack pushDisplay:_application];
	}
}

- (void)activate
{
	SBApplication *fromApp = [SBWActiveDisplayStack topApplication];
	NSString *fromIdent = fromApp ? [fromApp displayIdentifier] : @"com.apple.springboard";
	if (![fromIdent isEqualToString:_displayIdentifier]) {
		// App to switch to is not the current app
		// NOTE: Save the identifier for later use
		//deactivatingApp = [fromIdent copy];
		
		if ([fromIdent isEqualToString:@"com.apple.springboard"]) {
			// Switching from SpringBoard; simply activate the target app
			[_application setDisplaySetting:0x4 flag:YES]; // animate
			// Activate the target application
			[SBWPreActivateDisplayStack pushDisplay:_application];
		} else {
			// Switching from another app
			if (![_displayIdentifier isEqualToString:@"com.apple.springboard"]) {
				// Switching to another app; setup app-to-app
				[_application setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
				[_application setActivationSetting:0x20000 flag:YES]; // appToApp
				[_application setDisplaySetting:0x4 flag:YES]; // animate
				
				// Activate the target application (will wait for
				// deactivation of current app)
				[SBWPreActivateDisplayStack pushDisplay:_application];
			}
			
			// Deactivate the current application
			
			// If Backgrounder is installed, enable backgrounding for current application
			UIApplication *sharedApp = [UIApplication sharedApplication];
			if ([sharedApp respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
				[sharedApp setBackgroundingEnabled:YES forDisplayIdentifier:fromIdent];
			
			// NOTE: Must set animation flag for deactivation, otherwise
			// application window does not disappear (reason yet unknown)
			[fromApp setDeactivationSetting:0x2 flag:YES]; // animate
			
			// Deactivate by moving from active stack to suspending stack
			[SBWActiveDisplayStack popDisplay:fromApp];
			[SBWSuspendingDisplayStack pushDisplay:fromApp];
		}
	}
}

- (void)writeSnapshotToDisk
{
	if (!_snapshotFilePath && _snapshotData) {
		// Generate filename
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
		CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
		CFRelease(uuid);
		NSString *fileName = [NSString stringWithFormat:@"ProSwitcher-%@.cache", uuidString];
		CFRelease(uuidString);
		_snapshotFilePath = [[PSWApplication snapshotPath] stringByAppendingPathComponent:fileName];
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		size_t width = CGImageGetWidth(_snapshotImage);
		size_t height = CGImageGetHeight(_snapshotImage);
		size_t stride = CGImageGetBytesPerRow(_snapshotImage);
		[_snapshotData writeToFile:_snapshotFilePath atomically:NO];
		[_snapshotData release];
		_snapshotData = [[NSData alloc] initWithContentsOfMappedFile:_snapshotFilePath];
		CGContextRef context = CGBitmapContextCreate((void *)[_snapshotData bytes], width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGColorSpaceRelease(colorSpace);
		CGImageRelease(_snapshotImage);
		_snapshotImage = CGBitmapContextCreateImage(context);
		CGContextRelease(context);
		if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
			[_delegate applicationSnapshotDidChange:self];
	}
}

@end

CHDeclareClass(SBApplication)

CHMethod1(void, SBApplication, _relaunchAfterAbnormalExit, BOOL, something)
{
	if ([[self displayIdentifier] isEqualToString:ignoredRelaunchDisplayIdentifier]) {
		[ignoredRelaunchDisplayIdentifier release];
		ignoredRelaunchDisplayIdentifier = nil;
	} else {
		CHSuper1(SBApplication, _relaunchAfterAbnormalExit, something);
	}
}

CHConstructor {
	CHLoadLateClass(SBApplication);
	CHHook1(SBApplication, _relaunchAfterAbnormalExit);
}

