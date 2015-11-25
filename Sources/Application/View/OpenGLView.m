//---------------------------------------------------------------------------------
//
//	File: OpenGLView.m
//
// Abstract: OpenGLView.m demonstrates how to denoise images using
//           Core image denoise filters and OpenGL framebuffer objects.
// 			 
//  Disclaimer: IMPORTANT:  This Apple software is supplied to you by
//  Inc. ("Apple") in consideration of your agreement to the following terms, 
//  and your use, installation, modification or redistribution of this Apple 
//  software constitutes acceptance of these terms.  If you do not agree with 
//  these terms, please do not use, install, modify or redistribute this 
//  Apple software.
//  
//  In consideration of your agreement to abide by the following terms, and
//  subject to these terms, Apple grants you a personal, non-exclusive
//  license, under Apple's copyrights in this original Apple software (the
//  "Apple Software"), to use, reproduce, modify and redistribute the Apple
//  Software, with or without modifications, in source and/or binary forms;
//  provided that if you redistribute the Apple Software in its entirety and
//  without modifications, you must retain this notice and the following
//  text and disclaimers in all such redistributions of the Apple Software. 
//  Neither the name, trademarks, service marks or logos of Apple Inc. may 
//  be used to endorse or promote products derived from the Apple Software 
//  without specific prior written permission from Apple.  Except as 
//  expressly stated in this notice, no other rights or licenses, express
//  or implied, are granted by Apple herein, including but not limited to
//  any patent rights that may be infringed by your derivative works or by
//  other works in which the Apple Software may be incorporated.
//  
//  The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
//  MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
//  THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
//  OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//  
//  IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
//  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
//  MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
//  AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//  STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// 
//  Copyright (c) 2009 Apple Inc., All rights reserved.
//
//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#import "OpenGLView.h"

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constants

//---------------------------------------------------------------------------------

static const unichar kESCKey = 27; 

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities

//---------------------------------------------------------------------------------

static NSOpenGLPixelFormat *GetOpenGLPixelFormat()
{
	// Antialised, hardware accelerated without fallback to the software renderer.
	
	NSOpenGLPixelFormatAttribute   attribsAntialised[] =
	{
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize,  8,
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, 1,
		NSOpenGLPFASamples, 4,
		0
	};
	
	NSOpenGLPixelFormat  *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribsAntialised];
	
	if( pixelFormat == nil ) 
	{
		// If we can't get the desired pixel format then fewer attributes 
		// will be rerquested.
		
		NSOpenGLPixelFormatAttribute   attribsBasic[] =
		{
			NSOpenGLPFAAccelerated,
			NSOpenGLPFADoubleBuffer,
			NSOpenGLPFAColorSize, 24,
			NSOpenGLPFAAlphaSize,  8,
			0
		};
		
		pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribsBasic];
		
		[[NSAlert alertWithMessageText:@"WARNING" 
						 defaultButton:@"Okay" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:@"Basic pixel format was allocated!"] runModal];
	} // if
	
	return( pixelFormat );
} // GetOpenGLPixelFormat

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Enumerated Types

//---------------------------------------------------------------------------------

enum CIDenoiseFilterType
{
	kCIMedianFilter = 1,
	kCINRFilter
};

typedef enum CIDenoiseFilterType CIDenoiseFilterType;

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -

//---------------------------------------------------------------------------------

@implementation OpenGLView

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Post Notification

//---------------------------------------------------------------------------------

- (void) postOpenGLViewTerminationNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(glViewWillTerminate:)
												 name:@"NSApplicationWillTerminateNotification"
											   object:NSApp];
} // postOpenGLViewTerminationNotification

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Designated Initializer

//---------------------------------------------------------------------------------

- (void) initFullScreen
{
	fullScreenOptions = [[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]  
													 forKey:NSFullScreenModeSetting] retain];
	
	fullScreen = [[NSScreen mainScreen] retain];
} // initFullScreen

//---------------------------------------------------------------------------------
//
// Turn on VBL syncing for swaps
//
//---------------------------------------------------------------------------------

- (void) initSyncToVBL:(NSOpenGLContext *)theContext
{	
	GLint syncVBL = 1;
	
	[theContext setValues:&syncVBL 
			 forParameter:NSOpenGLCPSwapInterval];
} // initSyncToVBL

//---------------------------------------------------------------------------------

- (void) initCoreImage:(NSOpenGLContext *)theContext
		   pixelFormat:(NSOpenGLPixelFormat *)thePixelFormat
{
	imagePathname = [[[NSBundle mainBundle] pathForResource: @"lena_noisy" 
													 ofType: @"png"] retain];
	
	if( imagePathname )
	{
		denoise = [[CIDenoiseFilter alloc] initCIDenoiseFilterWithFile:imagePathname
															   context:theContext 
														   pixelFormat:thePixelFormat];
		
		
		[denoise update];
		
		[self setNeedsDisplay:YES];
	} // if
} // initCoreImage

//---------------------------------------------------------------------------------

- (id)initWithFrame:(NSRect)frameRect
{	
	NSOpenGLPixelFormat  *pixelFormat = GetOpenGLPixelFormat();
		
	if( pixelFormat )
	{
		self = [super initWithFrame:frameRect 
						pixelFormat:pixelFormat];
		
		if( self )
		{
			NSOpenGLContext *context = [self openGLContext];
			
			if( context )
			{
				[self initFullScreen];
				[self initSyncToVBL:context];
				[self initCoreImage:context 
						pixelFormat:pixelFormat];
				
				imageAuthor = [ImageAuthor new];
			} // if
			
			zoom = 1.0f;
		} // if

		[pixelFormat release];
		
		[self postOpenGLViewTerminationNotification];
	} // if
		
	return( self );
} // initWithFrame

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - OpenGL Initializer

//---------------------------------------------------------------------------------

- (void) prepareOpenGL
{
	//-----------------------------------------------------------------
	//
	// For some OpenGL implementations, texture coordinates generated 
	// during rasterization aren't perspective correct. However, you 
	// can usually make them perspective correct by calling the API
	// glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST).  Colors 
	// generated at the rasterization stage aren't perspective correct 
	// in almost every OpenGL implementation, / and can't be made so. 
	// For this reason, you're more likely to encounter this problem 
	// with colors than texture coordinates.
	//
	//-----------------------------------------------------------------
	
	glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST);
	
	// Set up the projection
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	
	glFrustum(-0.3, 0.3, 0.0, 0.6, 1.0, 8.0);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glTranslatef(0.0f, 0.0f, -2.0f);
	
	// Turn on depth test
    glEnable(GL_DEPTH_TEST);
	
	// front - or back - facing facets can be culled
    glEnable(GL_CULL_FACE);

	// Clear to black nothing fancy.
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	
	// Setup blending function 
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
} // prepareOpenGL

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Deallocate

//---------------------------------------------------------------------------------

- (void) cleanUpOpenGLView
{
	// Default image pathname
	
	if( imagePathname )
	{
		[imagePathname release];
	} // if
	
	// Pixel imagrer
	
	if( imageAuthor )
	{
		[imageAuthor release];
	}
	
	// Core Image denoise filter
	
	if( denoise )
	{
		[denoise release];
	} // if
	
	// Release full screen resources
	
	if( fullScreenOptions )
	{
		[fullScreenOptions release];
		
		fullScreenOptions = nil;
	} // if
	
	if( fullScreen )
	{
		[fullScreen release];
		
		fullScreen = nil;
	} // if
} // cleanUpOpenGLView

//---------------------------------------------------------------------------------

- (void) dealloc
{
	[self cleanUpOpenGLView];
	[super dealloc];
} // dealloc

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Transformations

//---------------------------------------------------------------------------------

- (void) setPrespective
{
	GLdouble  width  = (GLdouble)bounds.size.width;
	GLdouble  height = (GLdouble)bounds.size.height;
	GLdouble  aspect =  width / height;
	GLdouble  right  =  0.15 * aspect * zoom;
	GLdouble  left   = -right;
	GLdouble  top    =  0.15 * zoom;
	GLdouble  bottom = -top;
	GLdouble  zNear  =  0.3;;
	GLdouble  zFar   =  100.0;
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	
	glFrustum(left, right, bottom, top, zNear, zFar);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
} // setPrespective

//---------------------------------------------------------------------------------

- (void) setViewport
{
	bounds = [self bounds];
	
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	glViewport(0, 0, bounds.size.width, bounds.size.height);
} // setViewport

//---------------------------------------------------------------------------------
//
// the GL_TEXTURE_RECTANGLE_ARB doesn't use normalized coordinates
// scale the texture matrix to "increase" the texture coordinates
// back to the image size
//
//---------------------------------------------------------------------------------

- (void) setImageScale
{
	CGSize imageSize = [denoise size];
	
	glScalef(imageSize.width,imageSize.height,1.0f);
} // setImageScale

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Drawing

//---------------------------------------------------------------------------------
//
// Setup OpenGL with a perspective projection, updtae translation matrix, and
// then drae the denoised image.
//
//---------------------------------------------------------------------------------

- (void) drawScene
{
	[self setViewport];
	[self setImageScale];
	[self setPrespective];
	
	glTranslatef(0.0f, 0.0f, -2.0f);

	[denoise display];
} // updatePerspective

//---------------------------------------------------------------------------------
//
// Render the scene
//
//---------------------------------------------------------------------------------

- (void)drawRect:(NSRect)theRect
{	
	// Set the currrent OpenGL context
	[[self openGLContext] makeCurrentContext];

	// Render using the resulting texture
	[self drawScene];
	
	// Flush the OpenGL context asynchronously
	[[self openGLContext] flushBuffer];
} // drawRect

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilties

//---------------------------------------------------------------------------------

- (void) updateFilter:(NSImage *)theImage
{
	if( theImage ) 
	{
		// Load a new image
		[denoise updateWithData:[theImage TIFFRepresentation]];
	} // if
	else 
	{		
		if( imagePathname )
		{
			// Reload the default image
			[denoise updateWithFile:imagePathname];
		} // if
	} // else
	
	[self setNeedsDisplay:YES];
} // updateFilter

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - View Filters

//---------------------------------------------------------------------------------
//
// Based on selected denoise fiilter, we set the target to the selected filter.
//
//---------------------------------------------------------------------------------

- (void) setFilter:(const NSInteger)theFilter
{
	switch( theFilter )
	{
		case kCIMedianFilter:
			[denoise enableMedianFilter];
			break;
		case kCINRFilter:
		default:
			[denoise enableNRFilter];
			break;
	} // switch
	
	[self setNeedsDisplay:YES];
} // setFilter

//---------------------------------------------------------------------------------

- (void) setNoiseLevel:(const CGFloat)theNoiseLevel
{
	[denoise setNoiseLevel:theNoiseLevel];
	
	[self setNeedsDisplay:YES];
} // setNoiseLevel

//---------------------------------------------------------------------------------

- (void) setInputSharpness:(const CGFloat)theInputSharpness
{
	[denoise setInputSharpness:theInputSharpness];
	
	[self setNeedsDisplay:YES];
} // setInputSharpness

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Saving Image

//---------------------------------------------------------------------------------

- (void) imageSaveAs:(CFStringRef)theImageName
			  UTType:(CFStringRef)theImageUTType
{
	void   *data = [denoise buffer];
	CGSize  size = [denoise size];
	
	BOOL imaged = [imageAuthor imageWithSize:&size 
									  pixels:data];
	
	if( imaged )
	{
		[imageAuthor imageSaveAs:theImageName 
						  UTType:theImageUTType];
	} // if
} // imageSaveAs

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Full Screen Mode

//---------------------------------------------------------------------------------

- (void) fullScreenEnable
{
	[self enterFullScreenMode:fullScreen  
				  withOptions:fullScreenOptions];
} // fullScreenEnable

//---------------------------------------------------------------------------------

- (void) fullScreenDisable
{
	[self exitFullScreenModeWithOptions:fullScreenOptions];
} // fullScreenDisable

//---------------------------------------------------------------------------------

- (void) setFullScreenMode
{
	if( ![self isInFullScreenMode] )
	{
		[self fullScreenEnable];
	} // if
} // setFullScreenMode

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Key Events

//---------------------------------------------------------------------------------

- (void) keyDown:(NSEvent *)theEvent
{
    unichar keyPressed = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
	
    if( keyPressed == kESCKey )
	{
		if( [self isInFullScreenMode] )
		{
			[self fullScreenDisable];
		} // if
		else
		{
			[self fullScreenEnable];
		} // if
    } // if
} // keyDown

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Mouse Events

//---------------------------------------------------------------------------------

- (void)mouseDown:(NSEvent *)theEvent
{
	lastMousePoint = [self convertPoint:[theEvent locationInWindow] 
							   fromView:nil];
} // mouseDown

//---------------------------------------------------------------------------------

- (void)rightMouseDown:(NSEvent *)theEvent
{
	lastMousePoint = [self convertPoint:[theEvent locationInWindow] 
							   fromView:nil];
} // rightMouseDown

//---------------------------------------------------------------------------------

- (void)mouseDragged:(NSEvent *)theEvent
{
	if( [theEvent modifierFlags] & NSRightMouseDown )
	{
		[self rightMouseDragged:theEvent];
	} // if
	else
	{
		NSPoint mouse = [self convertPoint:[theEvent locationInWindow] 
								  fromView:nil];
		
		lastMousePoint = mouse;
		
		[self setNeedsDisplay:YES];
	} // else
} // mouseDragged

//---------------------------------------------------------------------------------

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	NSPoint mouse = [self convertPoint:[theEvent locationInWindow] 
							  fromView:nil];
	
	zoom += 0.01f * (lastMousePoint.y - mouse.y);
	
	if( zoom < 0.05f )
	{
		zoom = 0.05f;
	} // if
	else if( zoom > 2.0f )
	{
		zoom = 2.0f;
	} // else if
	
	lastMousePoint = mouse;
	
	[self setPrespective];
	
	[self setNeedsDisplay:YES];
} // rightMouseDragged

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Notification

//---------------------------------------------------------------------------------
//
// It's important to clean up our rendering objects before we terminate -- 
// Cocoa will not specifically release everything on application termination, 
// so we explicitly call our clean up routine ourselves.
//
//---------------------------------------------------------------------------------

- (void) glViewWillTerminate:(NSNotification *)notification
{
	[self cleanUpOpenGLView];
} // glViewWillTerminate

//---------------------------------------------------------------------------------

@end

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

