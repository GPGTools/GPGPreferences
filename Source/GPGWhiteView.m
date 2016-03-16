//
//  GPGWhiteView.m
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import "GPGWhiteView.h"

@implementation GPGWhiteView

- (void)drawRect:(NSRect)dirtyRect {
	CGFloat radius = 20;
	
	// This rect will be drawn out of the clipping rect. Only the shadow of the rect is really drawn on screen.
	NSRect rect = NSInsetRect(self.bounds, radius, radius);
	rect.origin.y -= self.bounds.size.height;

	// The offset of the shadow macthes the offset of the rect. So it will be in original location.
	NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	shadow.shadowOffset = NSMakeSize(0, self.bounds.size.height);
	shadow.shadowBlurRadius = radius;
	shadow.shadowColor = [NSColor whiteColor];

	[shadow set];
	[[NSColor blackColor] set];
	NSRectClip(self.bounds);
	NSRectFill(rect);
	
	[super drawRect:dirtyRect];
}



@end
