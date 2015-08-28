//
//  ViewController.m
//  OWLHeart
//
//  Created by Sosnovshchenko Alexander on 11/14/14.
//  Copyright (c) 2014 Sosnovshchenko Alexander. All rights reserved.
//

#import <GPUImage/GPUImage.h>
#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak) IBOutlet UIView *previewView;

@property (nonatomic, strong) UIImage *borderView;
@property (nonatomic, strong) CIDetector *faceDetector;

@property (nonatomic, strong) IBOutlet UIImageView *faceView;


// CV tutorial

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupAVCapture];
    self.borderView = [UIImage imageNamed:@"Viewfinder.gif"];
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}


- (void)setupAVCapture
{
    NSError *error = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    // Select a video device, make an input
    AVCaptureDevice *device = nil;
    
    // Try to find the front facing camera
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (d.position == AVCaptureDevicePositionFront) {
            device = d;
            self.isUsingFrontFacingCamera = YES;
            break;
        }
    }
    
    // Fall back to the default camera.
    if(!device)
    {
        self.isUsingFrontFacingCamera = NO;
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    // get the input device
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if( !error ) {
        
        // add the input to the session
        if ( [session canAddInput:deviceInput] ){
            [session addInput:deviceInput];
        }
        
        
        // Make a video data output
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                                                      forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [self.videoDataOutput setVideoSettings:rgbOutputSettings];
        [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
        
        // create a serial dispatch queue used for the sample buffer delegate
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
        
        if ( [session canAddOutput:self.videoDataOutput] ){
            [session addOutput:self.videoDataOutput];
        }
        
        // get the output for doing face detection.
        [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        CALayer *rootLayer = [self.previewView layer];
        [rootLayer setMasksToBounds:YES];
        [self.previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:self.previewLayer];
        [session startRunning];
        
    }
    session = nil;
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:
                                  [NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss" 
                                                  otherButtonTitles:nil];
        [alertView show];
        [self teardownAVCapture];
    }
}

// clean up capture setup
- (void)teardownAVCapture
{
    self.videoDataOutput = nil;
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // get the image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    
    // HERE YOU  HAVE CIIMAGE!!!

    
    if (attachments) {
        CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                   options:@{CIDetectorImageOrientation:@5,
                                                             CIDetectorAccuracy:CIDetectorAccuracyHigh,
                                                             CIDetectorTracking:@YES}];
    for (CIFeature *feature in features) {
        NSString *type = feature.type;
        CGRect frame = feature.bounds;
        CGRect foreheadFrame = CGRectMake(frame.origin.x,
                                          frame.origin.y + frame.size.height/3,
                                          frame.size.width/6.5,
                                          frame.size.height/3);
        if ([type isEqualToString:@"Face"]) {
            CIImage *faceImage = [ciImage imageByCroppingToRect:foreheadFrame];
            UIImageOrientation originalOrientation = UIImageOrientationRight;
            CGFloat originalScale = 1.f;
            CIContext *context = [CIContext contextWithOptions:@{}];
            CGImageRef img = [context createCGImage:faceImage fromRect:[faceImage extent]];
            UIImage *newImage = [UIImage imageWithCGImage:img
                                                    scale:originalScale
                                              orientation:originalOrientation];
            if (newImage.size.height > 0 &&
                newImage.size.width > 0 &&
                nil != newImage &&
                !CGSizeEqualToSize(CGSizeZero, newImage.size)) {
            GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:newImage];
            GPUImageContrastFilter *customFilter = [GPUImageContrastFilter new];
                customFilter.contrast = 4.0;
//                customFilter.red = 1.0;
//                customFilter.green = 0.0;
//                customFilter.blue = 0.0;
//                
            [stillImageSource addTarget:customFilter];
            [customFilter useNextFrameForImageCapture];
            [stillImageSource processImage];
            
                GPUImageAverageColor *averageFilter = [GPUImageAverageColor new];
                [averageFilter setColorAverageProcessingFinishedBlock:^(CGFloat redComponent,
                                                                        CGFloat greenComponent,
                                                                        CGFloat blueComponent,
                                                                        CGFloat alphaComponent,
                                                                        CMTime frameTime) {
                    NSLog(@"%f",redComponent);
                }];
                [stillImageSource addTarget:averageFilter];
//                [averageFilter useNextFrameForImageCapture];
                [stillImageSource processImage];
                
                
            UIImage *currentFilteredVideoFrame = [customFilter imageFromCurrentFramebuffer];
            
//            GPUImageRGBFilter
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.faceView setImage:currentFilteredVideoFrame];
            });
            }
        }
    }
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self drawFaces:features
            forVideoBox:cleanAperture
            orientation:curDeviceOrientation];
    });
}



// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector
// to detect features and for each draw the green border in a layer and set appropriate orientation
- (void)drawFaces:(NSArray *)features
      forVideoBox:(CGRect)clearAperture
      orientation:(UIDeviceOrientation)orientation
{
    NSArray *sublayers = [NSArray arrayWithArray:[self.previewLayer sublayers]];
    NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
    NSInteger featuresCount = [features count], currentFeature = 0;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    // hide all the face layers
    for ( CALayer *layer in sublayers ) {
        if ( [[layer name] isEqualToString:@"FaceLayer"] )
            [layer setHidden:YES];
    }
    
    if ( featuresCount == 0 ) {
        [CATransaction commit];
        return; // early bail.
    }
    
    CGSize parentFrameSize = [self.previewView frame].size;
    NSString *gravity = [self.previewLayer videoGravity];
    CGRect previewBox = [ViewController videoPreviewBoxForGravity:gravity
                                                        frameSize:parentFrameSize
                                                     apertureSize:clearAperture.size];
    
    for ( CIFaceFeature *ff in features ) {
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];
        
        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        
        CALayer *featureLayer = nil;
        
        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }
        
        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [[CALayer alloc]init];
            featureLayer.contents = (id)self.borderView.CGImage;
            [featureLayer setName:@"FaceLayer"];
            [self.previewLayer addSublayer:featureLayer];
            featureLayer = nil;
        }
        [featureLayer setFrame:faceRect];
        
        currentFeature++;
    }
    
    [CATransaction commit];
}

// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
}


@end
