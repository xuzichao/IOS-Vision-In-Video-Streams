//
//  ViewController.m
//  VisionFaceTracking
//
//  Created by Zichao Xu on 2018/6/12.
//  Copyright © 2018年 YaoJingdeWeiba. All rights reserved.
//

#import "ViewController.h"
#import "MobileNet.h"
#import "UIImage+Utils.h"
#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic,strong) UIView *realTimeView;   //实时显示的区域容器
@property (nonatomic,strong) AVCaptureVideoPreviewLayer* previewLayer; //实时显示摄像的区域
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutPut;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic,strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) UIImageView *maskView;
@property (nonatomic, strong)VNDetectFaceLandmarksRequest *faceRequest;
@property (nonatomic, strong)VNCoreMLRequest *coreMLRequest;

@property (nonatomic, strong) UILabel *googleLabel;
@property (nonatomic,strong)UIButton *nextBtn;
@property (nonatomic,assign)BOOL coreMlMode;

@end

@implementation ViewController

- (void)didReceiveMemoryWarning
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initAVCapturWritterConfig];
    [self setUpSubviews];
    [self initVN];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self startVideoCapture];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self stopVideoCapture];
    
}

- (void)initAVCapturWritterConfig
{
    self.session = [[AVCaptureSession alloc] init];
    
    //视频
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if (videoDevice.isFocusPointOfInterestSupported && [videoDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        [videoDevice lockForConfiguration:nil];
        [videoDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [videoDevice unlockForConfiguration];
    }
    
    AVCaptureDeviceInput *cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:nil];
    
    
    if ([self.session canAddInput:cameraDeviceInput]) {
        [self.session addInput:cameraDeviceInput];
    }
    
    //视频
    self.videoOutPut = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey, nil];
    [self.videoOutPut setVideoSettings:outputSettings];
    if ([self.session canAddOutput:self.videoOutPut]) {
        [self.session addOutput:self.videoOutPut];
    }
    self.videoConnection = [self.videoOutPut connectionWithMediaType:AVMediaTypeVideo];
    self.videoConnection.enabled = NO;
    [self.videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
}

- (void)setUpSubviews
{
    //容器
    self.realTimeView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.realTimeView];
    
    //实时图像预览
    self.previewLayer.frame = self.realTimeView.frame;
    [self.realTimeView.layer addSublayer:self.previewLayer];
    
    self.maskView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"1"]];
    self.maskView.hidden = YES;
    [self.realTimeView addSubview:self.maskView];
    
    self.googleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 40,100, 40)];
    self.googleLabel.textAlignment = NSTextAlignmentCenter;
    self.googleLabel.font = [UIFont systemFontOfSize:20];
    self.googleLabel.textColor = [UIColor whiteColor];
    self.googleLabel.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.googleLabel];
    
    self.nextBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 100,self.view.frame.size.height - 40, 100, 40)];
    self.nextBtn.backgroundColor = [UIColor blackColor];
    [self.nextBtn setTitle:@"切换CoreML" forState:UIControlStateNormal];
    self.nextBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.nextBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.nextBtn addTarget:self action:@selector(nextCoreML) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nextBtn];
}

- (void)startVideoCapture
{
    [self.session startRunning];
    self.videoConnection.enabled = YES;
    self.videoQueue = dispatch_queue_create("videoQueue", NULL);
    [self.videoOutPut setSampleBufferDelegate:self queue:self.videoQueue];
}

- (void)stopVideoCapture
{
    [self.videoOutPut setSampleBufferDelegate:nil queue:nil];
    self.videoConnection.enabled = NO;
    self.videoQueue = nil;
    [self.session stopRunning];
}

- (void)initVN
{
    //人脸识别
    self.faceRequest = [[VNDetectFaceLandmarksRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        
        VNDetectFaceLandmarksRequest *faceRequest = (VNDetectFaceLandmarksRequest*)request;
        
        VNFaceObservation *firstObservation = [faceRequest.results firstObject];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (firstObservation) {
                
                CGRect boundingBox = [firstObservation boundingBox];
                
                CGRect rect = VNImageRectForNormalizedRect(boundingBox,self.realTimeView.frame.size.width,self.realTimeView.frame.size.height);
                CGRect frame = CGRectMake(self.realTimeView.frame.size.width - rect.origin.x - rect.size.width, self.realTimeView.frame.size.height - rect.origin.y - rect.size.height, rect.size.width, rect.size.height);
                self.maskView.frame = frame;
                self.maskView.hidden = NO;
            }
            else {
                self.maskView.hidden = YES;
            }
        });
        
    }];
    
    //实物识别
    VNCoreMLModel *vnModel = [VNCoreMLModel modelForMLModel:[MobileNet new].model error:nil];
    self.coreMLRequest = [[VNCoreMLRequest alloc] initWithModel:vnModel completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNCoreMLRequest *coreR = (VNCoreMLRequest *)request;
        VNClassificationObservation *firstObservation = [coreR.results firstObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (firstObservation) {
                self.googleLabel.text = firstObservation.identifier;
            }
            else {
                self.googleLabel.text = @"";
            }
        });
    }];
    self.coreMLRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
}

- (void)nextCoreML
{
    if (!self.coreMlMode) {
        self.coreMlMode = YES;
        self.maskView.hidden = YES;
        self.googleLabel.hidden = NO;
        [self.nextBtn setTitle:@"切换人脸识别" forState:UIControlStateNormal];
    }
    else {
        self.coreMlMode = NO;
        self.maskView.hidden = NO;
        self.googleLabel.hidden = YES;
        [self.nextBtn setTitle:@"切换实体检测" forState:UIControlStateNormal];
    }
}

#pragma mark --AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.coreMlMode) {
        UIImage *image = [UIImage imageFromSampleBuffer:sampleBuffer];
        UIImage *scaledImage = [image scaleToSize:CGSizeMake(224, 224)];
        CVPixelBufferRef buffer = [image pixelBufferFromCGImage:scaledImage];
        
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:buffer options:@{}];
        NSError *error;
        [handler performRequests:@[self.coreMLRequest] error:&error];
    }
    else {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:@{}];
        NSError *error;
        [handler performRequests:@[self.faceRequest] error:&error];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}


@end
