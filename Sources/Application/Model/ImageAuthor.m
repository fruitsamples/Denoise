//---------------------------------------------------------------------------------
//
//	File: ImageAuthor.m
//
// Abstract: Utility toolkit to save pixels as bmp, pict, png, gif, jpeg, or
//           jp2000 file(s).
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

#import "ImageAuthor.h"

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constants

//---------------------------------------------------------------------------------

static const size_t kImageMaxSPP = 4;		// Image maximum samples-per-pixel
static const size_t kImageMaxBPC = 8;		// Image maximum bits-per-component

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -

//---------------------------------------------------------------------------------

@implementation ImageAuthor

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Default Initializer

//---------------------------------------------------------------------------------
//
// Default initializer for setting basic properties for authoring an image file.
//
//---------------------------------------------------------------------------------

- (id) init
{
	self = [super init];
	
	if( self )
	{
		CFIndex capacity = 1;
		
		imageRef   = NULL;
		bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little;	// XRGB Little Endian
		colorSpace = CGColorSpaceCreateWithName( kCGColorSpaceGenericRGB );
		imageDict  = CFDictionaryCreateMutable(kCFAllocatorDefault, 
											   capacity,
											   &kCFTypeDictionaryKeyCallBacks,
											   &kCFTypeDictionaryValueCallBacks);
	} // if
	
	return( self );
} // init

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------------

- (void) dealloc
{
	if( colorSpace != NULL )
	{
		CGColorSpaceRelease( colorSpace );
		
		colorSpace = NULL;
	} // if
	
	if( imageDict != NULL )
	{
		CFRelease( imageDict );
		
		imageDict = NULL;
	} // if
	
	if( imageRef != NULL )
	{
		CGImageRelease( imageRef );
		
		imageRef = NULL;
	} // if
	
	[super dealloc];
} // dealloc

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Accessors

//---------------------------------------------------------------------------------

- (CGImageRef) imageRef
{
	return( imageRef );
} // imageRef

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities

//---------------------------------------------------------------------------------
//
// Utility to update a pixel backing store with new data of a certain rectangular
// size with width and height.
//
//---------------------------------------------------------------------------------

- (BOOL) imageWithSize:(const CGSize *)theImageSize
				pixels:(void *)theImagePixels
{
	BOOL imageUpdated = NO;
	
	if( theImagePixels != NULL )
	{
		// Compute bitmap context properties
		size_t bitsPerComponent = kImageMaxBPC;
		size_t width            = (size_t)theImageSize->width;
		size_t height           = (size_t)theImageSize->height;
		size_t rowBytes         = kImageMaxSPP * width;

		// Create a bitmap context of size = spp * width * height
		CGContextRef contextRef = CGBitmapContextCreate(theImagePixels, 
														width, 
														height, 
														bitsPerComponent,
														rowBytes, 
														colorSpace, 
														bitmapInfo);
		
		if( contextRef != NULL )
		{
			// Release an old opaque image reference in favor of a new one
			if( imageRef != NULL )
			{
				CGImageRelease( imageRef );
				
				imageRef = NULL;
			} // if
			
			// Get an opaque image reference from bitmap context
			imageRef = CGBitmapContextCreateImage( contextRef );
			
			// Bitmap context is not needed
			CGContextRelease( contextRef );
			
			imageUpdated = imageRef != NULL;
		} // if
	} // if
	
	return( imageUpdated );
} // imageWithSize

//---------------------------------------------------------------------------------
//
// Save an opaque image reference as bmp, pict, png, gif, jpeg, or jp2000 file.
//
//---------------------------------------------------------------------------------

- (BOOL) imageSaveAs:(CFStringRef)theImageName
			  UTType:(CFStringRef)theImageUTType
{
	BOOL imageSaved = NO;
	
	if( ( imageRef != NULL ) && ( theImageName ) )
	{
		Boolean isDirectory = false;
		
		// Get a URL associated with an image file name
		CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, 
														 theImageName,
														 kCFURLPOSIXPathStyle, 
														 isDirectory);
		
		if( fileURL != NULL )
		{
			// Set the properties for authoring an image file
			CFIndex                 fileImageIndex = 1;
			CFMutableDictionaryRef  fileDict       = NULL;
			CFStringRef             fileUTType     = ( theImageUTType != NULL ) ? ( theImageUTType ) : kUTTypeJPEG;
			
			// Create an image destination opaque reference for authoring an image file
			CGImageDestinationRef imageDest = CGImageDestinationCreateWithURL(fileURL, 
																			  fileUTType, 
																			  fileImageIndex, 
																			  fileDict);
			
			if( imageDest != NULL )
			{
				// Add an opaque image reference to the destination
				CGImageDestinationAddImage(imageDest, 
										   imageRef,
										   imageDict);
				
				// Close the image file
				CGImageDestinationFinalize( imageDest ) ;
				
				// Image destination opaque reference is not needed
				CFRelease( imageDest );
				
				imageSaved = YES;
			} // if
			
			CFRelease( fileURL );
		} // if
	} // if
	
	return( imageSaved );
} // imageSaveAs

//---------------------------------------------------------------------------------

@end

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------
