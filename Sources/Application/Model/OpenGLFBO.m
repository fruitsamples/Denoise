//---------------------------------------------------------------------------------
//
//	File: OpenGLFBO.h
//
// Abstract: Utility toolkit to manage a framebuffer object.
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

#import <OpenGL/glu.h>

//---------------------------------------------------------------------------------

#import "OpenGLFBO.h"

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constants

//---------------------------------------------------------------------------------

static const size_t kTextureMaxSPP = 4;		// Texture maximum samples-per-pixel

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -

//---------------------------------------------------------------------------------

@implementation OpenGLFBO

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Check FBO

//---------------------------------------------------------------------------------
//
// Make sure the framebuffer extenstion is supported
//
// Get the extenstion name string.  It is a space-delimited list of the OpenGL 
// extenstions that are supported by the current renderer.
//
//---------------------------------------------------------------------------------

- (BOOL) isFBOSupported
{
	const GLubyte *extString = glGetString(GL_EXTENSIONS);
	const GLubyte *extName   = (const GLubyte *)"GL_EXT_framebuffer_object";
	
	GLboolean isValidExtension = gluCheckExtension(extName, extString);
	
	if( !isValidExtension )
	{
		[[NSAlert alertWithMessageText:@"WARNING" 
						 defaultButton:@"Okay" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:@"This system does not support framebuffer extension!"] runModal];
	} // if
	
	return( isValidExtension ? YES : NO );
} // isFBOSupported

//---------------------------------------------------------------------------------
//
// Make sure the FBO was created succesfully.
//
//---------------------------------------------------------------------------------

- (BOOL) isFBOComplete
{
	BOOL isStatusOk = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) == GL_FRAMEBUFFER_COMPLETE_EXT;
	
	if( !isStatusOk )
	{
		[[NSAlert alertWithMessageText:@"WARNING" 
						 defaultButton:@"Okay" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:@"Framebuffer Object creation or update failed!"] runModal];
	} // if
	
	return( isStatusOk );
} // isFBOComplete

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Prepare OpenGL

//---------------------------------------------------------------------------------
//
// Sanity check against maximum OpenGL texture size.  If bigger adjust to maximum 
// possible size while maintain the aspect ratio.
//
//---------------------------------------------------------------------------------

- (void) initAspectRatio:(const CGRect *)theImageFrame
{
	GLint maxTexSize = 0;
	
	glGetIntegerv( GL_MAX_TEXTURE_SIZE, &maxTexSize );
	
	imageBuffer.width  = (size_t)theImageFrame->size.width;
	imageBuffer.height = (size_t)theImageFrame->size.height;
	
	aspectRatio = theImageFrame->size.width / theImageFrame->size.height;

	if( ( imageBuffer.width > maxTexSize ) || ( imageBuffer.height > maxTexSize ) ) 
	{
		if( aspectRatio > 1.0f )
		{
			imageBuffer.width  = maxTexSize; 
			imageBuffer.height = maxTexSize / (size_t)aspectRatio;
		} // if
		else
		{
			imageBuffer.width  = maxTexSize * (size_t)aspectRatio;
			imageBuffer.height = maxTexSize; 
		} // else
	} // if
} // initAspectRatio

//---------------------------------------------------------------------------------

- (BOOL) newTexture
{
	if( !texture )
	{
		glGenTextures(1, &texture);
	} // if
	
	if( texture )
	{
		// Enable texture rectangle environment
		glEnable(GL_TEXTURE_RECTANGLE_ARB);
		
		// Initialize framebuffer texture
		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
		
		// Set some default texture parameters
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		// Use GPU's format combination of GL_BGRA and GL_UNSIGNED_INT_8_8_8_8_REV
		glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 
					 0, 
					 GL_RGBA,
					 imageBuffer.width, 
					 imageBuffer.height, 
					 0, 
					 GL_BGRA, 
					 GL_UNSIGNED_INT_8_8_8_8_REV, 
					 NULL);
	} // if
	
	return( texture != 0 );
} // newTexture

//---------------------------------------------------------------------------------

- (BOOL)newFBO
{
	if( !framebuffer )
	{
		glGenFramebuffersEXT(1, &framebuffer);
	} // if
	
	if( framebuffer )
	{
		// Bind to FBO
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, framebuffer);
		
		// Attach texture to the FBO as its color destination
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, 
								  GL_COLOR_ATTACHMENT0_EXT,
								  GL_TEXTURE_RECTANGLE_ARB, 
								  texture, 
								  0);
		// Check FBO validity
		[self isFBOComplete];
		
		// unbind FBO 
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
	} // if
	
	return( framebuffer != 0 );
} // newFBO

//---------------------------------------------------------------------------------
//
// Create or update the hardware accelerated offscreen area framebuffer object.
//
//---------------------------------------------------------------------------------

- (void) initFBO:(const CGRect *)theImageFrame
{
	[self initAspectRatio:theImageFrame];
	
	if( [self newTexture] )
	{
		if( [self newFBO] )
		{
			imageBuffer.rowBytes = kTextureMaxSPP * imageBuffer.width;
			imageBuffer.data     = malloc( imageBuffer.rowBytes * imageBuffer.height );
			
			if( imageBuffer.data == NULL )
			{
				[[NSAlert alertWithMessageText:@"WARNING" 
								 defaultButton:@"Okay" 
							   alternateButton:nil 
								   otherButton:nil 
					 informativeTextWithFormat:@"Buffer allocation failed!"] runModal];
			} // if
		} // if
	} // if
} // initFBO

//---------------------------------------------------------------------------------
//
// Generate a quad and compile into a display list.  This quad will be used in
// a display method to draw a texture.
//
//---------------------------------------------------------------------------------

- (BOOL) initQuad
{
	if( !displayList )
	{
		displayList = glGenLists( 1 );
		
		if( displayList )
		{
			glNewList( displayList, GL_COMPILE );
			
			glBegin(GL_QUADS);
			{
				glTexCoord2f( 1.0f, 1.0f ); 
				glVertex2f( 1.0f, 1.0f );
				
				glTexCoord2f( 0.0f, 1.0f ); 
				glVertex2f( -1.0f, 1.0f );
				
				glTexCoord2f( 0.0f, 0.0f ); 
				glVertex2f( -1.0f, -1.0f );
				
				glTexCoord2f( 1.0f, 0.0f ); 
				glVertex2f( 1.0f, -1.0f );
			}
			glEnd();
			
			glEndList();
		} // if
	} // if
	
	return( displayList != 0 );
} // initQuad

//---------------------------------------------------------------------------------

- (id) initFBOWithFrame:(const CGRect *)theImageFrame;
{	
	self = [super init];
	
	if( self )
	{
		framebuffer = 0;
		texture     = 0;
		displayList = 0;
		
		if( [self isFBOSupported] )
		{
			[self initFBO:theImageFrame];
			[self initQuad];
		} // if
	} // if
	
	return( self );
} // initWithFrame

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Deallocate

//---------------------------------------------------------------------------------

- (void) releaseTexture
{
	if( texture )
	{
		glDeleteTextures(1, &texture);
		
		texture = 0;
	} // if
} // releaseTexture

//---------------------------------------------------------------------------------

- (void) releaseFBO
{
	if( framebuffer )
	{
		glDeleteFramebuffersEXT(1, &framebuffer);
		
		framebuffer = 0;
	} // if
} // releaseFBO

//---------------------------------------------------------------------------------

- (void) releaseQuad
{
	if( displayList )
	{
		glDeleteLists( displayList, 1 );
		
		displayList = 0;
	} // if
} // releaseQuad

//---------------------------------------------------------------------------------

- (void) releaseImageBuffer
{
	if( imageBuffer.data != NULL )
	{
		free( imageBuffer.data );
		
		imageBuffer.data = NULL;
	} // if
} // releaseImage

//---------------------------------------------------------------------------------

- (void) cleanUpFBO
{
	// Delete the image buffer
	[self releaseImageBuffer];
	
	// Delete the texture
	[self releaseTexture];
	
	// Delete the FBO
	[self releaseFBO];
	
	// Delete the quad display list
	[self releaseQuad];
} // cleanUpFBO

//---------------------------------------------------------------------------------

- (void) dealloc
{
	[self cleanUpFBO];
	
	[super dealloc];
} // dealloc

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Render Context

//---------------------------------------------------------------------------------
//
// Bind a framebuffer ans setup orthographic projection
//
//---------------------------------------------------------------------------------

- (void) bind
{
	// Bind FBO 
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, framebuffer);
	
	// Map an orthographic projection or screen aligned 2D area 
	// for drawing an image
	
	glViewport(0, 0, imageBuffer.width, imageBuffer.height);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, imageBuffer.width, 0, imageBuffer.height, -1, 1);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glClear(GL_COLOR_BUFFER_BIT);
} // bind

//---------------------------------------------------------------------------------
//
// Unbind from theframebuffer
//
//---------------------------------------------------------------------------------

- (void) unbind
{
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
} // unbind

//---------------------------------------------------------------------------------
//
// Inorder to update the contents of FBO, when subclassing, and if you wish to 
// use the update method, implement this method.
//
//---------------------------------------------------------------------------------

- (void) render
{
	return;
} // render

//---------------------------------------------------------------------------------
//
// Update the framebuffer
//
//---------------------------------------------------------------------------------

- (void) update
{
	[self bind];
	[self render];
	[self unbind];
} // update

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Render Scene

//---------------------------------------------------------------------------------
//
// Draw the image using the texture from the FBO
//
//---------------------------------------------------------------------------------

- (void) display
{
	// Use the FBO bound texture
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB,texture);
	
	// GL_REPLACE is used since we want the image colors unaffected 
	// by the quad color
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	// Draw an image into a quad (display list) with the proper 
	// aspect ratio
	glPushMatrix();
	{
		glScalef(aspectRatio,1.0f,1.0f);
		glCallList(displayList);
	}
	glPopMatrix();
} // display

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Image Readback

//---------------------------------------------------------------------------------
//
// Read back the pixels from the framebuffer
//
//---------------------------------------------------------------------------------

- (void) readPixels
{
	// Read image from the framebuffer
	glReadPixels(0, 
				 0, 
				 imageBuffer.width, 
				 imageBuffer.height, 
				 GL_BGRA, 
				 GL_UNSIGNED_BYTE, 
				 imageBuffer.data);
	
	// Vertical reflect the pixels in the buffer
	vImage_Error imageError = vImageVerticalReflect_ARGB8888(&imageBuffer, 
															 &imageBuffer, 
															 kvImageHighQualityResampling);
	
	if( imageError != kvImageNoError )
	{
		NSLog( @">> ERROR[%lu]: Vertical reflect geometerical operation failed!", imageError);
	} // if
} // readPixels

//---------------------------------------------------------------------------------

- (void *) buffer
{
	// bind buffer and make attachment
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, framebuffer);
	
	// Read back the image from the framebuffer
	[self readPixels];
	
	// unbind buffer and detach
	glBindFramebufferEXT( GL_FRAMEBUFFER_EXT, 0 );
	
	return( imageBuffer.data );
} // buffer

//---------------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Accessors

//---------------------------------------------------------------------------------

- (void) setFrame:(const CGRect *)theImageFrame
{
	GLint  imageWidth  = (GLint)theImageFrame->size.width;
	GLint  imageHeight = (GLint)theImageFrame->size.height;
	
	if( ( imageBuffer.width != imageWidth ) || ( imageBuffer.height != imageHeight ) )
	{
		[self releaseImageBuffer];
		
		[self initFBO:theImageFrame];
	} // if
} // setFrame

//---------------------------------------------------------------------------------

@end

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

