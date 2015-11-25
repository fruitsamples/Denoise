//---------------------------------------------------------------------------------
//
//	File: CIDenoiseFilter.m
//
// Abstract: Utility class for managing Core Image denoise filters.
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

#import "CIDenoiseFilter.h"

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Function Pointer - Prototype

//---------------------------------------------------------------------------------

typedef void (*OpenGLRenderFuncPtr)(CGFloat    *ciFilterParams,
									CGRect      ciExtent,
									CIContext  *ciContext,
									CIImage    *ciImage,
									CIFilter   *ciFilter);

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Function Pointer - Implementations

//---------------------------------------------------------------------------------
//
// Render to texture using Core Image Median filter.
//
//---------------------------------------------------------------------------------

static void glRenderUsingMedianFilter(CGFloat    *ciFilterParams,
									  CGRect      ciExtent,
									  CIContext  *ciContext,
									  CIImage    *ciImage,
									  CIFilter   *ciFilter)
{
	// Update images
	[ciFilter setValue:ciImage forKey:@"inputImage"];
	
	// Render CI 
	[ciContext drawImage: [ciFilter valueForKey:@"outputImage"]
				 atPoint: CGPointZero  
				fromRect: ciExtent];
} // glRenderUsingMedianFilter

//---------------------------------------------------------------------------------
//
// Render to texture using Core Image noise reduction filter.
//
//---------------------------------------------------------------------------------

static void glRenderUsingNRFilter(CGFloat    *ciFilterParams,
								  CGRect      ciExtent,
								  CIContext  *ciContext,
								  CIImage    *ciImage,
								  CIFilter   *ciFilter)
{
	// Update values for filters
	[ciFilter setValue: [NSNumber numberWithFloat: ciFilterParams[0]] forKey: @"inputNoiseLevel"];
	[ciFilter setValue: [NSNumber numberWithFloat: ciFilterParams[1]] forKey: @"inputSharpness"];
	
	// Update images
	[ciFilter setValue:ciImage forKey:@"inputImage"];

	// Render CI 
	[ciContext drawImage: [ciFilter valueForKey:@"outputImage"]
				 atPoint: CGPointZero  
				fromRect: ciExtent];
} // glRenderUsingNRFilter

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Function Pointers - Global

//---------------------------------------------------------------------------------

static OpenGLRenderFuncPtr  glRenderFuncPtr = NULL;

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -

//---------------------------------------------------------------------------------

@implementation CIDenoiseFilter

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Prepare OpenGL

//---------------------------------------------------------------------------------
//
// Create CIContext based on OpenGL context and pixel format.
//
//---------------------------------------------------------------------------------

- (BOOL) newCIContext:(NSOpenGLContext *)theContext
		  pixelFormat:(NSOpenGLPixelFormat *)thePixelFormat
{
	BOOL bContextCreated = NO;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	if( colorSpace != NULL )
	{
		// Create CIContext from the OpenGL context.
		ciContext = [CIContext contextWithCGLContext:[theContext CGLContextObj] 
										 pixelFormat:[thePixelFormat CGLPixelFormatObj]
										  colorSpace:colorSpace
											 options:nil];
		
		if( !ciContext )
		{ 
			[[NSAlert alertWithMessageText:@"ERROR" 
							 defaultButton:@"Okay" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:@"CoreImage context creation failed!"] runModal];
		} // if
		else 
		{
			[ciContext retain];
			
			bContextCreated = YES;
		} // else
		
		CGColorSpaceRelease(colorSpace);
	} // if
	
	// Created succesfully
	return( bContextCreated );
} // newCIContext

//---------------------------------------------------------------------------
//
// Create the Core Image denoise filters
//
//---------------------------------------------------------------------------

- (void) initCIDenoiseFilters
{
	ciMedianFilter = [CIFilter filterWithName: @"CIMedianFilter"];
	
	if( ciMedianFilter )
	{
		[ciMedianFilter setDefaults];
		[ciMedianFilter setValue:ciImage forKey:@"inputImage"];
		[ciMedianFilter retain];
	} // if

	ciNRFilter = [CIFilter filterWithName: @"CINoiseReduction"];
	
	if( ciNRFilter )
	{
		[ciNRFilter setDefaults];
		[ciNRFilter setValue:ciImage forKey:@"inputImage"];
		[ciNRFilter retain];
	} // if
	
	// Set the default denoising filter to be the Core Image Media filter
	
	ciDenoiseFilter = ciMedianFilter;
	glRenderFuncPtr = &glRenderUsingMedianFilter;
} // initCIDenoiseFilters

//---------------------------------------------------------------------------

- (id) initCIDenoiseFilterWithFile:(NSString *)theImageFile
						   context:(NSOpenGLContext *)theContext
					   pixelFormat:(NSOpenGLPixelFormat *)thePixelFormat
{	
	// Load the image
	NSURL *imageURL = [NSURL fileURLWithPath:theImageFile];
	
	if( imageURL )
	{
		// Initialize Core Image with the contents of a file
		CIImage *ciImageFromFile = [[CIImage imageWithContentsOfURL:imageURL] retain];
		
		// Get the size of the image we are going to need throughout
		CGRect imageBounds = [ciImageFromFile extent];
		
		self = [super initFBOWithFrame:&imageBounds];
		
		if( self )
		{
			ciImage  = ciImageFromFile;
			ciExtent = imageBounds;
			
			ciDenoiseParams[0] = 0.0;
			ciDenoiseParams[1] = 0.0;
			
			[self newCIContext:theContext pixelFormat:thePixelFormat];
			[self initCIDenoiseFilters];
		} // if
	} // if
	
	return( self );
} // initCIDenoiseFilterWithFile

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Deallocate

//---------------------------------------------------------------------------------

- (void) releaseCIContext
{
	if( ciContext )
	{
		[ciContext release];
		
		ciContext = nil;
	} // if
} // releaseCIContext

//---------------------------------------------------------------------------------

- (void) releaseCIImage
{
	if( ciImage )
	{
		[ciImage release];
		
		ciImage = nil;
	} // if
} // releaseCIImage

//---------------------------------------------------------------------------------

- (void) dealloc
{
	[self releaseCIContext];
	[self releaseCIImage];
	
	[super dealloc];
} // dealloc

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Render Context

//---------------------------------------------------------------------------------
//
// This method actually renders with Core Image to the OpenGL managed, hardware 
// accelerated offscreen buffer.
//
//---------------------------------------------------------------------------------

- (void) render
{
	glRenderFuncPtr(ciDenoiseParams,
					ciExtent,
					ciContext,
					ciImage,
					ciDenoiseFilter);
} // renderCIContextToFBO

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Getters

//---------------------------------------------------------------------------------

- (CGSize) size
{
	return( ciExtent.size );
} // size

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Setters

//---------------------------------------------------------------------------------

- (void) setNoiseLevel:(const CGFloat)theNoiseLevel
{
	// The input is between 0.0 to 100.0.  Scale the value
	// to 0.0 to 0.10 for Core Image noise reduction filter.
	ciDenoiseParams[0] = theNoiseLevel * 0.001f;
	
	// Render Core Image to the FBO
	[self update];
} // setNoiseLevel

//---------------------------------------------------------------------------------

- (void) setInputSharpness:(const CGFloat)theInputSharpness
{
	// The input is between 0.0 to 100.0.  Scale the value
	// to 0.0 to 2.0 for Core Image noise reduction filter.
	ciDenoiseParams[1] = theInputSharpness * 0.02f;

	// Render Core Image to the FBO
	[self update];
} // setInputSharpness

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Filter Selection

//---------------------------------------------------------------------------------

- (void) enableMedianFilter
{
	ciDenoiseFilter = ciMedianFilter;
	glRenderFuncPtr = &glRenderUsingMedianFilter;
	
	[self update];
} // enableMedianFilter

//---------------------------------------------------------------------------------

- (void) enableNRFilter
{
	ciDenoiseFilter = ciNRFilter;
	glRenderFuncPtr = &glRenderUsingNRFilter;

	[self update];
} // enableNRFilter

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Updating

//---------------------------------------------------------------------------------

- (void) updateCIImage
{
	// Update geometry
	ciExtent = [ciImage extent];
	
	// Update FBO for new size and check for correctness
	[self setFrame:&ciExtent];
	
	// Render Core Image to the FBO
	[self update];
} // updateCIImage

//---------------------------------------------------------------------------------

- (void) updateWithData:(NSData *)theImageData
{
	// Delete the old CI image
	[self releaseCIImage];
	
	// Load a new image
	ciImage = [[CIImage imageWithData:theImageData] retain];
	
	// Now update the CI image
	[self updateCIImage];
} // updateWithData

//---------------------------------------------------------------------------------

- (void) updateWithFile:(NSString *)theImageFile
{
	// Delete the old CI image
	[self releaseCIImage];
	
	// Load an image from a file
	ciImage = [[CIImage imageWithContentsOfURL:[NSURL fileURLWithPath:theImageFile 
														  isDirectory:NO]] retain];
	
	// Now update the CI image
	[self updateCIImage];
} // updateWithFile

//---------------------------------------------------------------------------------

@end

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

