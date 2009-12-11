#import "PSWSnapshotPageView.h"
#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

@implementation PSWSnapshotPageView
@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;
@synthesize tapsToActivate = _tapsToActivate;


#pragma mark Private Methods

- (void)_applyEmptyText
{
	if ([_emptyText length] != 0 && [_applications count] == 0) {
		if (!_emptyLabel) {
			UIFont *font = [UIFont boldSystemFontOfSize:16.0f];
			CGFloat height = [_emptyText sizeWithFont:font].height;
			CGRect bounds = [self bounds];
			bounds.origin.x = 0.0f;
			bounds.origin.y = (NSInteger)((bounds.size.height - height) / 2.0f);
			bounds.size.height = height;
			_emptyLabel = [[UILabel alloc] initWithFrame:bounds];
			_emptyLabel.backgroundColor = [UIColor clearColor];
			_emptyLabel.textAlignment = UITextAlignmentCenter;
			_emptyLabel.font = font;
			_emptyLabel.textColor = [UIColor whiteColor];
			[self addSubview:_emptyLabel];
		} else {
			CGRect bounds = [_emptyLabel bounds];
			bounds.origin.y = (NSInteger)(([self bounds].size.height - bounds.size.height) / 2.0f);
			[_emptyLabel setBounds:bounds];
		}
		_emptyLabel.text = _emptyText;
	} else {
		[_emptyLabel removeFromSuperview];
		[_emptyLabel release];
		_emptyLabel = nil;
	}
}

/*
 There is a reason we are being so hacky here. We want to use paging, as supplied by UIScrollView, but, that forces each page to
 be the full size of the UIScrollView itself. Not good. Originally, we had a custom paging implementation here, but I think my 
 way works better.
 
 The way I do this is I hack UIScrollView by setting it to have a larger frame, then setting the bounds smaller and telling it to
 *not* clip to its bounds: making the pages to the left and right show up. Since the bounds are smaller, paging works as expected,
 but as we don't clip to the bounds, the other pages are still displayed.
 
 Not the nicest way to do things, but sometimes (way too often) hacking UIKit is the only method besides reimplementing the view
 yourself, which never comes out quite as good as you would hope :(.
 */

- (void)_layoutViews
{
	CGRect frame = self.frame;
	CGFloat pageWidth = frame.size.width - (_snapshotInset * 2);
	NSLog(@"pageWidth: %f", pageWidth);
	NSInteger pageCount = [_applications count];
	[_pageControl setNumberOfPages:pageCount];
	
	[_scrollView setFrame:CGRectMake(_snapshotInset, 0.0f, pageWidth, frame.size.height)];
	[_scrollView setContentSize:CGSizeMake((pageWidth * pageCount) + 1.0f, frame.size.height)];
	
	NSLog(@"frame: %@", NSStringFromCGRect(_scrollView.frame));
	NSLog(@"content size: %@", NSStringFromCGSize(_scrollView.contentSize));
	
	CGRect pageFrame = CGRectMake(0.0f, 0.0f, pageWidth, frame.size.height);
	for (int i = 0; i < pageCount; i++) {
		if ([_snapshotViews count] <= i)
		{
			PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:pageFrame application:[_applications objectAtIndex:i]];
			snapshot.delegate = self;
			[_scrollView addSubview:snapshot];
			[_snapshotViews addObject:snapshot];
			[snapshot release];
		}
		
		PSWSnapshotView *view = [_snapshotViews objectAtIndex:i];
		[view setFrame:pageFrame];
		NSLog(@"snapshot frame: %@", NSStringFromCGRect(pageFrame));
		pageFrame.origin.x += pageWidth;
	}
	
	[self _applyEmptyText];
}


#pragma mark Public Methods

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;
{
	if ((self = [super initWithFrame:frame]))
	{
		_applicationController = [applicationController retain];
		[applicationController setDelegate:self];
		_applications = [[applicationController activeApplications] mutableCopy];
		NSUInteger numberOfPages = [_applications count];
		
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, frame.size.height - 27.0f, frame.size.width, 27.0f)];
		[_pageControl setNumberOfPages:numberOfPages];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		_scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height)];
		[_scrollView setClipsToBounds:NO];
		[_scrollView setPagingEnabled:YES];
		[_scrollView setContentSize:CGSizeZero];
		[_scrollView setShowsHorizontalScrollIndicator:NO];
		[_scrollView setShowsVerticalScrollIndicator:NO];
		[_scrollView setScrollsToTop:NO];
		[_scrollView setDelegate:self];
		[_scrollView setBackgroundColor:[UIColor clearColor]];
		[_scrollView setContentOffset:CGPointZero];
		[self addSubview:_scrollView];

		_snapshotViews = [[NSMutableArray alloc] init];
		
		[self setBackgroundColor:[UIColor clearColor]];
		[self setClipsToBounds:NO];
		
		[self _layoutViews];
		
	}
	return self;
}

- (void)dealloc
{
	[_applicationController setDelegate:nil];
	[_applicationController release];
	[_emptyText release];
	[_emptyLabel release];
	[_scrollView release];
	[_pageControl release];
	[_snapshotViews release];
	[_applications release];
	[super dealloc];
}

- (NSArray *)snapshotViews
{
	return [[_snapshotViews copy] autorelease];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat pageWidth = [scrollView bounds].size.width;
	NSInteger page = floor(([scrollView contentOffset].x - pageWidth / 2) / pageWidth) + 1.0f;
	
	if ([_pageControl currentPage] != page) {
		[_pageControl setCurrentPage:page];
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didFocusApplication:)])
			[_delegate snapshotPageView:self didFocusApplication:[self focusedApplication]];
	}
}

#pragma mark PSWSnapshotViewDelegate

- (void)snapshotViewClosed:(PSWSnapshotView *)snapshot
{
	if ([_delegate respondsToSelector:@selector(snapshotPageView:didCloseApplication:)])
		[_delegate snapshotPageView:self didCloseApplication:[snapshot application]];
}

- (void)snapshotViewTapped:(PSWSnapshotView *)snapshot withCount:(NSInteger)tapCount
{
	if (tapCount == _tapsToActivate) {
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didSelectApplication:)])
			[_delegate snapshotPageView:self didSelectApplication:[snapshot application]];
	}
}

- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshot
{
	if ([_delegate respondsToSelector:@selector(snapshotPageViewShouldExit:)])
		[_delegate snapshotPageViewShouldExit:self];
}


#pragma mark Properties

- (PSWApplication *)focusedApplication
{
	if ([_applications count])
		return [_applications objectAtIndex:[_pageControl currentPage]];
	return nil;
}

- (void)setFocusedApplication:(PSWApplication *)application
{
	[self setFocusedApplication:application animated:YES];
}

- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated
{
	NSInteger index = [self indexOfApplication:application];
	if (index != NSNotFound && index != [_pageControl currentPage]) {
		[_pageControl setCurrentPage:index];
		[_scrollView setContentOffset:CGPointMake(_scrollView.bounds.size.width * index, 0.0f) animated:animated];
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didFocusApplication:)])
			[_delegate snapshotPageView:self didFocusApplication:application];
	}
}

- (BOOL)showsTitles
{
	return _showsTitles;
}
- (void)setShowsTitles:(BOOL)showsTitles
{
	if (_showsTitles != showsTitles) {
		_showsTitles = showsTitles;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setShowsTitle:showsTitles];
	}
}

- (BOOL)showsCloseButtons
{
	return _showsCloseButtons;
}
- (void)setShowsCloseButtons:(BOOL)showsCloseButtons
{
	if (_showsCloseButtons != showsCloseButtons) {
		_showsCloseButtons = showsCloseButtons;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setShowsCloseButton:showsCloseButtons];
	}
}

- (BOOL)allowsSwipeToClose
{
	return _showsCloseButtons;
}
- (void)setAllowsSwipeToClose:(BOOL)allowsSwipeToClose
{
	if (_allowsSwipeToClose != allowsSwipeToClose) {
		_allowsSwipeToClose = allowsSwipeToClose;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setAllowsSwipeToClose:allowsSwipeToClose];
	}
}

- (NSString *)emptyText
{
	return _emptyText;
}
- (void)setEmptyText:(NSString *)emptyText
{
	if (_emptyText != emptyText) {
		if (![_emptyText isEqualToString:_emptyText]) {
			[_emptyText autorelease];
			_emptyText = [emptyText copy];
			[self _applyEmptyText];
		}
	}
}

- (CGFloat)roundedCornerRadius
{
	return _roundedCornerRadius;
}
- (void)setRoundedCornerRadius:(CGFloat)roundedCornerRadius
{
	if (_roundedCornerRadius != roundedCornerRadius) {
		_roundedCornerRadius = roundedCornerRadius;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setRoundedCornerRadius:_roundedCornerRadius];
	}
}

- (CGFloat)snapshotInset
{
	return _snapshotInset;
}

-(void)setSnapshotInset:(CGFloat)snapshotInset
{
	if (_snapshotInset != snapshotInset) {
		_snapshotInset = snapshotInset;

		[self _layoutViews];
	}
}

- (NSInteger)indexOfApplication:(PSWApplication *)application
{
	return [_applications indexOfObject:application];
}


#pragma mark PSWApplicationControllerDelegate

- (void)applicationController:(PSWApplicationController *)ac applicationDidLaunch:(PSWApplication *)application
{
	if (![_applications containsObject:application]) {
		[_applications addObject:application];
		CGRect frame = [_scrollView bounds];
		frame.size.width -= _snapshotInset;
		PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:frame application:application];
		snapshot.delegate = self;
		snapshot.showsTitle = _showsTitles;
		snapshot.showsCloseButton = _showsCloseButtons;
		snapshot.allowsSwipeToClose = _allowsSwipeToClose;
		snapshot.roundedCornerRadius = _roundedCornerRadius;
		[_scrollView addSubview:snapshot];
		[_snapshotViews addObject:snapshot];
		[snapshot release];
		[self _layoutViews];
	}
}

- (void)didRemoveSnapshotView:(NSString *)animationID finished:(NSNumber *)finished context:(PSWSnapshotView *)context
{
	[context removeFromSuperview];
	self.userInteractionEnabled = YES;
}

- (void)applicationController:(PSWApplicationController *)ac applicationDidExit:(PSWApplication *)application
{
	NSInteger index = [_applications indexOfObject:application];
	if (index != NSNotFound) {
		[_applications removeObject:application];
		PSWSnapshotView *snapshot = [_snapshotViews objectAtIndex:index];
		snapshot.delegate = nil;
		[_snapshotViews removeObjectAtIndex:index];
		[UIView beginAnimations:nil context:snapshot];
		[UIView setAnimationDuration:0.33f];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(didRemoveSnapshot:finished:context:)];
		CGRect frame = snapshot.frame;
		frame.origin.y -= frame.size.height;
		snapshot.frame = frame;
		snapshot.alpha = 0.0f;
		[self _layoutViews];
		[UIView commitAnimations];
	}
}

@end
