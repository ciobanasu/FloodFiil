//
//  UIImage+FloodFill.m
//  ImageFloodFilleDemo
//
//  Created by chintan on 15/07/13.
//  Copyright (c) 2013 ZWT. All rights reserved.
//

#import "UIImage+FloodFill.h"

#define DEBUG_ANTIALIASING 0

@implementation UIImage (FloodFill)

- (UIImage *) floodFillFromPoint:(CGPoint)startPoint withColor:(UIColor *)newColor andTolerance:(NSInteger)tolerance
{
    return [self floodFillFromPoint:startPoint withColor:newColor andTolerance:tolerance useAntiAlias:YES];
}

- (UIImage *) floodFillFromPoint:(CGPoint)startPoint withColor:(UIColor *)newColor andTolerance:(NSInteger)tolerance useAntiAlias:(BOOL)antiAlias
{
    @try
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGImageRef imageRef = [self CGImage];
        
        NSUInteger width = CGImageGetWidth(imageRef);
        NSUInteger height = CGImageGetHeight(imageRef);
        NSUInteger bytesPerPixel = CGImageGetBitsPerPixel(imageRef) / 8;
        NSUInteger bytesPerRow = CGImageGetBytesPerRow(imageRef);
        NSUInteger bitsPerComponent = CGImageGetBitsPerComponent(imageRef);

        unsigned char *imageData = malloc(height * width * bytesPerPixel);
      
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
      
        if (kCGImageAlphaLast == (uint32_t)bitmapInfo ||
            kCGImageAlphaFirst == (uint32_t)bitmapInfo)
        {
            bitmapInfo = (uint32_t)kCGImageAlphaPremultipliedLast;
        }
        
        CGContextRef context = CGBitmapContextCreate(imageData,
                                                     width,
                                                     height,
                                                     bitsPerComponent,
                                                     bytesPerRow,
                                                     colorSpace,
                                                     bitmapInfo);
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        
        //Get color at start point 
        NSUInteger byteIndex = (bytesPerRow * roundf(startPoint.y)) + roundf(startPoint.x) * bytesPerPixel;
        
        NSUInteger ocolor = getColorCode(byteIndex, imageData);
        
        if (compareColor(ocolor, 0, 0))
        {
            return nil;
        }
        
        //Convert newColor to RGBA value so we can save it to image.
        NSInteger newRed, newGreen, newBlue, newAlpha;
        
        const CGFloat *components = CGColorGetComponents(newColor.CGColor);

        if(CGColorGetNumberOfComponents(newColor.CGColor) == 2)
        {
            newRed   = newGreen = newBlue = components[0] * 255;
            newAlpha = components[1] * 255;
        }
        else if (CGColorGetNumberOfComponents(newColor.CGColor) == 4)
        {
            if ((bitmapInfo&kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Little)
            {
                newRed   = components[2] * 255;
                newGreen = components[1] * 255;
                newBlue  = components[0] * 255;
                newAlpha = 255;
            }
            else
            {
                newRed   = components[0] * 255;
                newGreen = components[1] * 255;
                newBlue  = components[2] * 255;
                newAlpha = 255;
            }
        }
        
        NSUInteger ncolor = (newRed << 24) | (newGreen << 16) | (newBlue << 8) | newAlpha;
        LinkedListStack *points = [[LinkedListStack alloc] initWithCapacity:500 incrementSize:500 andMultiplier:height];
        LinkedListStack *antiAliasingPoints = [[LinkedListStack alloc] initWithCapacity:500 incrementSize:500 andMultiplier:height];
        
        NSInteger x = roundf(startPoint.x);
        NSInteger y = roundf(startPoint.y);
        
        [points pushFrontX:x andY:y];
        NSUInteger color;
        BOOL spanLeft,spanRight;
        
        while ([points popFront:&x andY:&y] != INVALID_NODE_CONTENT)
        {
            byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
            
            color = getColorCode(byteIndex, imageData);
            
            while(y >= 0 && compareColor(ocolor, color, tolerance))
            {
                y--;
                
                if(y >= 0)
                {
                    byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
                
                    color = getColorCode(byteIndex, imageData);
                }
            }
            
            // Add the top most point on the antialiasing list
            if(y >= 0 && !compareColor(ocolor, color, 0))
            {
                [antiAliasingPoints pushFrontX:x andY:y];
            }
            
            y++;
            
            spanLeft = spanRight = NO;
            
            byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
            
            color = getColorCode(byteIndex, imageData);
            
            while (y < height && compareColor(ocolor, color, tolerance) && ncolor != color)
            {
                //Change old color with newColor RGBA value
                imageData[byteIndex + 0] = newRed;
                imageData[byteIndex + 1] = newGreen;
                imageData[byteIndex + 2] = newBlue;
                imageData[byteIndex + 3] = newAlpha;
                
                if(x > 0)
                {
                    byteIndex = (bytesPerRow * roundf(y)) + roundf(x - 1) * bytesPerPixel;
                    
                    color = getColorCode(byteIndex, imageData);
                    
                    if(!spanLeft && x > 0 && compareColor(ocolor, color, tolerance))
                    {
                        [points pushFrontX:(x - 1) andY:y];
                    
                        spanLeft = YES;
                    }
                    else if(spanLeft && x > 0 && !compareColor(ocolor, color, tolerance))
                    {
                        spanLeft = NO;
                    }
                    
                    // we can't go left. Add the point on the antialiasing list
                    if(!spanLeft && x > 0 && !compareColor(ocolor, color, tolerance) && !compareColor(ncolor, color, tolerance))
                    {
                        [antiAliasingPoints pushFrontX:(x - 1) andY:y];
                    }
                }
                
                if(x < width - 1)
                {
                    byteIndex = (bytesPerRow * roundf(y)) + roundf(x + 1) * bytesPerPixel;;
                    
                    color = getColorCode(byteIndex, imageData);
                    
                    if(!spanRight && compareColor(ocolor, color, tolerance))
                    {
                        [points pushFrontX:(x + 1) andY:y];
                        
                        spanRight = YES;
                    }
                    else if(spanRight && !compareColor(ocolor, color, tolerance))
                    {
                        spanRight = NO;
                    }
                    
                    // we can't go right. Add the point on the antialiasing list
                    if(!spanRight && !compareColor(ocolor, color, tolerance) && !compareColor(ncolor, color, tolerance))
                    {
                        [antiAliasingPoints pushFrontX:(x + 1) andY:y];
                    }
                }
                
                y++;
                
                if(y < height)
                {
                    byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
                
                    color = getColorCode(byteIndex, imageData);
                }
            }
            
            if (y<height)
            {
                byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
                color = getColorCode(byteIndex, imageData);

                if (!compareColor(ocolor, color, 0))
                    [antiAliasingPoints pushFrontX:x andY:y];
            }
        }

        NSUInteger antialiasColor = getColorCodeFromUIColor(newColor,bitmapInfo&kCGBitmapByteOrderMask );
        NSInteger red1   = ((0xff000000 & antialiasColor) >> 24);
        NSInteger green1 = ((0x00ff0000 & antialiasColor) >> 16);
        NSInteger blue1  = ((0x0000ff00 & antialiasColor) >> 8);
        NSInteger alpha1 =  (0x000000ff & antialiasColor);

        while ([antiAliasingPoints popFront:&x andY:&y] != INVALID_NODE_CONTENT)
        {
            byteIndex = (bytesPerRow * roundf(y)) + roundf(x) * bytesPerPixel;
            color = getColorCode(byteIndex, imageData);

            if (!compareColor(ncolor, color, 0))
            {
                NSInteger red2   = ((0xff000000 & color) >> 24);
                NSInteger green2 = ((0x00ff0000 & color) >> 16);
                NSInteger blue2 = ((0x0000ff00 & color) >> 8);
                NSInteger alpha2 =  (0x000000ff & color);

                if (antiAlias)
                {
                    imageData[byteIndex + 0] = (red1 + red2) / 2;
                    imageData[byteIndex + 1] = (green1 + green2) / 2;
                    imageData[byteIndex + 2] = (blue1 + blue2) / 2;
                    imageData[byteIndex + 3] = (alpha1 + alpha2) / 2;
                }
                else
                {
                    imageData[byteIndex + 0] = red2;
                    imageData[byteIndex + 1] = green2;
                    imageData[byteIndex + 2] = blue2;
                    imageData[byteIndex + 3] = alpha2;
                }
                
#if DEBUG_ANTIALIASING
                imageData[byteIndex + 0] = 0;
                imageData[byteIndex + 1] = 0;
                imageData[byteIndex + 2] = 255;
                imageData[byteIndex + 3] = 255;
#endif
            }
            
            // left
            if (x>0)
            {
                byteIndex = (bytesPerRow * roundf(y)) + roundf(x - 1) * bytesPerPixel;
                color = getColorCode(byteIndex, imageData);
                
                if (!compareColor(ncolor, color, 0))
                {
                    NSInteger red2   = ((0xff000000 & color) >> 24);
                    NSInteger green2 = ((0x00ff0000 & color) >> 16);
                    NSInteger blue2 = ((0x0000ff00 & color) >> 8);
                    NSInteger alpha2 =  (0x000000ff & color);
                    
                    if (antiAlias) {
                        imageData[byteIndex + 0] = (red1 + red2) / 2;
                        imageData[byteIndex + 1] = (green1 + green2) / 2;
                        imageData[byteIndex + 2] = (blue1 + blue2) / 2;
                        imageData[byteIndex + 3] = (alpha1 + alpha2) / 2;
                    } else {
                        imageData[byteIndex + 0] = red2;
                        imageData[byteIndex + 1] = green2;
                        imageData[byteIndex + 2] = blue2;
                        imageData[byteIndex + 3] = alpha2;
                    }
                    
#if DEBUG_ANTIALIASING
                    imageData[byteIndex + 0] = 0;
                    imageData[byteIndex + 1] = 0;
                    imageData[byteIndex + 2] = 255;
                    imageData[byteIndex + 3] = 255;
#endif
                }
            }
          
            if (x<width)
            {
                byteIndex = (bytesPerRow * roundf(y)) + MIN(width,roundf(x + 1)) * bytesPerPixel;
                color = getColorCode(byteIndex, imageData);
                
                if (!compareColor(ncolor, color, 0))
                {
                    NSInteger red2   = ((0xff000000 & color) >> 24);
                    NSInteger green2 = ((0x00ff0000 & color) >> 16);
                    NSInteger blue2 = ((0x0000ff00 & color) >> 8);
                    NSInteger alpha2 =  (0x000000ff & color);
                    
                    if (antiAlias)
                    {
                        imageData[byteIndex + 0] = (red1 + red2) / 2;
                        imageData[byteIndex + 1] = (green1 + green2) / 2;
                        imageData[byteIndex + 2] = (blue1 + blue2) / 2;
                        imageData[byteIndex + 3] = (alpha1 + alpha2) / 2;
                    }
                    else
                    {
                        imageData[byteIndex + 0] = red2;
                        imageData[byteIndex + 1] = green2;
                        imageData[byteIndex + 2] = blue2;
                        imageData[byteIndex + 3] = alpha2;
                    }

#if DEBUG_ANTIALIASING
                    imageData[byteIndex + 0] = 0;
                    imageData[byteIndex + 1] = 0;
                    imageData[byteIndex + 2] = 255;
                    imageData[byteIndex + 3] = 255;
#endif
                }

            }
            
            if (y>0)
            {
                byteIndex = (bytesPerRow * roundf(y - 1)) + roundf(x) * bytesPerPixel;
                color = getColorCode(byteIndex, imageData);
                
                if (!compareColor(ncolor, color, 0))
                {
                    NSInteger red2   = ((0xff000000 & color) >> 24);
                    NSInteger green2 = ((0x00ff0000 & color) >> 16);
                    NSInteger blue2 = ((0x0000ff00 & color) >> 8);
                    NSInteger alpha2 =  (0x000000ff & color);
                    
                    if (antiAlias)
                    {
                        imageData[byteIndex + 0] = (red1 + red2) / 2;
                        imageData[byteIndex + 1] = (green1 + green2) / 2;
                        imageData[byteIndex + 2] = (blue1 + blue2) / 2;
                        imageData[byteIndex + 3] = (alpha1 + alpha2) / 2;
                    }
                    else
                    {
                        imageData[byteIndex + 0] = red2;
                        imageData[byteIndex + 1] = green2;
                        imageData[byteIndex + 2] = blue2;
                        imageData[byteIndex + 3] = alpha2;
                    }
                    
#if DEBUG_ANTIALIASING
                    imageData[byteIndex + 0] = 0;
                    imageData[byteIndex + 1] = 0;
                    imageData[byteIndex + 2] = 255;
                    imageData[byteIndex + 3] = 255;
#endif
                }
            }
            
            if (y<height)
            {
                byteIndex = (bytesPerRow * MIN(height,roundf(y + 1))) + roundf(x) * bytesPerPixel;
                color = getColorCode(byteIndex, imageData);
                
                if (!compareColor(ncolor, color, 0))
                {
                    NSInteger red2   = ((0xff000000 & color) >> 24);
                    NSInteger green2 = ((0x00ff0000 & color) >> 16);
                    NSInteger blue2 = ((0x0000ff00 & color) >> 8);
                    NSInteger alpha2 =  (0x000000ff & color);
                    
                    if (antiAlias)
                    {
                        imageData[byteIndex + 0] = (red1 + red2) / 2;
                        imageData[byteIndex + 1] = (green1 + green2) / 2;
                        imageData[byteIndex + 2] = (blue1 + blue2) / 2;
                        imageData[byteIndex + 3] = (alpha1 + alpha2) / 2;
                    }
                    else
                    {
                        imageData[byteIndex + 0] = red2;
                        imageData[byteIndex + 1] = green2;
                        imageData[byteIndex + 2] = blue2;
                        imageData[byteIndex + 3] = alpha2;
                    }
                    
#if DEBUG_ANTIALIASING
                    imageData[byteIndex + 0] = 0;
                    imageData[byteIndex + 1] = 0;
                    imageData[byteIndex + 2] = 255;
                    imageData[byteIndex + 3] = 255;
#endif
                }

            }
        }

        CGImageRef newCGImage = CGBitmapContextCreateImage(context);
        
        UIImage *result = [UIImage imageWithCGImage:newCGImage scale:[self scale] orientation:UIImageOrientationUp];
        
        CGImageRelease(newCGImage);
        
        CGContextRelease(context);
    
        free(imageData);
        
        return result;
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception : %@", exception);
    }
}

NSUInteger getColorCode (NSUInteger byteIndex, unsigned char *imageData)
{
    NSUInteger red   = imageData[byteIndex];
    NSUInteger green = imageData[byteIndex + 1];
    NSUInteger blue  = imageData[byteIndex + 2];
    NSUInteger alpha = imageData[byteIndex + 3];
    
    return (red << 24) | (green << 16) | (blue << 8) | alpha;
}

bool compareColor (NSUInteger color1, NSUInteger color2, NSInteger tolorance)
{
    if(color1 == color2)
        return true;
    
    NSInteger red1   = ((0xff000000 & color1) >> 24);
    NSInteger green1 = ((0x00ff0000 & color1) >> 16);
    NSInteger blue1  = ((0x0000ff00 & color1) >> 8);
    NSInteger alpha1 =  (0x000000ff & color1);
    
    NSInteger red2   = ((0xff000000 & color2) >> 24);
    NSInteger green2 = ((0x00ff0000 & color2) >> 16);
    NSInteger blue2  = ((0x0000ff00 & color2) >> 8);
    NSInteger alpha2 =  (0x000000ff & color2);
    
    NSInteger diffRed   = labs(red2   - red1);
    NSInteger diffGreen = labs(green2 - green1);
    NSInteger diffBlue  = labs(blue2  - blue1);
    NSInteger diffAlpha = labs(alpha2 - alpha1);
    
    if( diffRed   > tolorance ||
        diffGreen > tolorance ||
        diffBlue  > tolorance ||
        diffAlpha > tolorance  )
    {
        return false;
    }
    
    return true;
}

NSUInteger getColorCodeFromUIColor(UIColor *color, CGBitmapInfo orderMask)
{
    NSInteger newRed, newGreen, newBlue, newAlpha;
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    if(CGColorGetNumberOfComponents(color.CGColor) == 2)
    {
        newRed   = newGreen = newBlue = components[0] * 255;
        newAlpha = components[1] * 255;
    }
    else if (CGColorGetNumberOfComponents(color.CGColor) == 4)
    {
        if (orderMask == kCGBitmapByteOrder32Little)
        {
            newRed   = components[2] * 255;
            newGreen = components[1] * 255;
            newBlue  = components[0] * 255;
            newAlpha = 255;
        }
        else
        {
            newRed   = components[0] * 255;
            newGreen = components[1] * 255;
            newBlue  = components[2] * 255;
            newAlpha = 255;
        }
    }
    else
    {
        newRed   = newGreen = newBlue = 0;
        newAlpha = 255;
    }
    
    NSUInteger ncolor = (newRed << 24) | (newGreen << 16) | (newBlue << 8) | newAlpha;

    return ncolor;
}

@end
