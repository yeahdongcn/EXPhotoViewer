//
//  EXPhotoViewer.m
//  EXPhotoViewerDemo
//
//  Created by Julio Carrettoni on 3/20/14.
//  Copyright (c) 2014 Julio Carrettoni. All rights reserved.
//

#import "EXPhotoViewer.h"

@interface EXPhotoViewer ()

@property (nonatomic, retain) UIScrollView *zoomeableScrollView;
@property (nonatomic, retain) UIImageView *theImageView;
@property (nonatomic, retain) UIView *tempViewContainer;
@property (nonatomic, assign) CGRect originalImageRect;
@property (nonatomic, retain) UIViewController *controller;
@property (nonatomic, retain) UIViewController *selfController;
@property (nonatomic, retain) UIView *originalImage;

@end

@implementation EXPhotoViewer

- (UINavigationController *)navigationControllerFromView:(UIView *)view
{
    id nextResponder = view;
    do {
        if ([nextResponder isKindOfClass:[UINavigationController class]]) {
            return nextResponder;
        }
    } while ((nextResponder = [nextResponder nextResponder]));
    
    return nil;
}

+ (void)showImageFrom:(UIView *)view
{
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (imageView.image) {
            EXPhotoViewer *viewer = [EXPhotoViewer new];
            [viewer showImageFrom:imageView];
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if ([button backgroundImageForState:UIControlStateNormal]) {
            EXPhotoViewer *viewer = [EXPhotoViewer new];
            [viewer showImageFrom:button];
        }
    }

}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
    
    UIScrollView* scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.maximumZoomScale = 10.f;
    scrollView.minimumZoomScale = 1.f;
    scrollView.delegate = self;
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview: scrollView];
    self.zoomeableScrollView = scrollView;
    
    UIImageView* imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [self.zoomeableScrollView addSubview: imageView];
    self.theImageView = imageView;
}

- (void)showImageFrom:(UIView *)view {
    
    UIViewController* controller = [self navigationControllerFromView:view];
    self.tempViewContainer = [[UIView alloc] initWithFrame:controller.view.bounds];
    self.tempViewContainer.backgroundColor = controller.view.backgroundColor;
    controller.view.backgroundColor = [UIColor blackColor];
    
    for (UIView* subView in controller.view.subviews) {
        [self.tempViewContainer addSubview:subView];
    }
    
    [controller.view addSubview:self.tempViewContainer];
    
    self.controller = controller;
    [controller.view addSubview:self.view];
    
    self.view.frame = controller.view.bounds;
    self.view.backgroundColor = [UIColor clearColor];
    [controller.view addSubview:self.view];
    
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        self.theImageView.image = imageView.image;
        self.originalImageRect = [imageView convertRect:imageView.bounds toView:self.view];
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        self.theImageView.image = [button backgroundImageForState:UIControlStateNormal];
        self.originalImageRect = [button convertRect:button.bounds toView:self.view];
    }

    self.theImageView.frame = self.originalImageRect;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
        self.tempViewContainer.layer.transform = CATransform3DMakeScale(0.9, 0.9, 0.9);
        self.theImageView.frame = [self centeredOnScreenImage:self.theImageView.image];
    } completion:^(BOOL finished) {
        [self adjustScrollInsetsToCenterImage];
        UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackgroundTap)];
        [self.view addGestureRecognizer:tap];
    }];
    
    self.selfController = self; //Stupid ARC I need to do this to avoid being dealloced :P
    self.originalImage = view;
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        imageView.image = nil;
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        [button setBackgroundImage:nil forState:UIControlStateNormal];
    }
}

- (void) onBackgroundTap {
    CGRect absoluteCGRect = [self.view convertRect:self.theImageView.frame fromView:self.theImageView.superview];
    self.zoomeableScrollView.contentOffset = CGPointZero;
    self.zoomeableScrollView.contentInset = UIEdgeInsetsZero;
    self.theImageView.frame = absoluteCGRect;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.theImageView.frame = self.originalImageRect;
        self.view.backgroundColor = [UIColor clearColor];
        self.tempViewContainer.layer.transform = CATransform3DIdentity;
    }completion:^(BOOL finished) {
        if ([self.originalImage isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)self.originalImage).image = self.theImageView.image;
        } else if ([self.originalImage isKindOfClass:[UIButton class]]) {
            [((UIButton *)self.originalImage) setBackgroundImage:self.theImageView.image forState:UIControlStateNormal];
        }
       
        self.controller.view.backgroundColor = self.tempViewContainer.backgroundColor;
        for (UIView* subView in self.tempViewContainer.subviews) {
            [self.controller.view addSubview:subView];
        }
        [self.view removeFromSuperview];
        [self.tempViewContainer removeFromSuperview];
    }];
    
    self.selfController = nil;//Ok ARC you can kill me now.
}

- (CGRect) centeredOnScreenImage:(UIImage*) image {
    CGSize imageSize = [self imageSizesizeThatFitsForImage:self.theImageView.image];
    CGPoint imageOrigin = CGPointMake(self.view.frame.size.width/2.0 - imageSize.width/2.0, self.view.frame.size.height/2.0 - imageSize.height/2.0);
    return CGRectMake(imageOrigin.x, imageOrigin.y, imageSize.width, imageSize.height);
}

- (CGSize) imageSizesizeThatFitsForImage:(UIImage*) image {
    if (!image)
        return CGSizeZero;
    
    CGSize imageSize = image.size;
    CGFloat ratio = MIN(self.view.frame.size.width/imageSize.width, self.view.frame.size.height/imageSize.height);
    ratio = MIN(ratio, 1.0);//If the image is smaller than the screen let's not make it bigger
    return CGSizeMake(imageSize.width*ratio, imageSize.height*ratio);
}

#pragma mark - ZOOM
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.theImageView;
}

- (void) adjustScrollInsetsToCenterImage {
    CGSize imageSize = [self imageSizesizeThatFitsForImage:self.theImageView.image];
    self.zoomeableScrollView.zoomScale = 1.0;
    self.theImageView.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
    self.zoomeableScrollView.contentSize = self.theImageView.frame.size;
    
    CGRect innerFrame = self.theImageView.frame;
    CGRect scrollerBounds = self.zoomeableScrollView.bounds;
    CGPoint myScrollViewOffset = self.zoomeableScrollView.contentOffset;
    
    if ( ( innerFrame.size.width < scrollerBounds.size.width ) || ( innerFrame.size.height < scrollerBounds.size.height ) )
    {
        CGFloat tempx = self.theImageView.center.x - ( scrollerBounds.size.width / 2 );
        CGFloat tempy = self.theImageView.center.y - ( scrollerBounds.size.height / 2 );
        myScrollViewOffset = CGPointMake( tempx, tempy);
    }
    
    UIEdgeInsets anEdgeInset = { 0, 0, 0, 0};
    if ( scrollerBounds.size.width > innerFrame.size.width )
    {
        anEdgeInset.left = (scrollerBounds.size.width - innerFrame.size.width) / 2;
        anEdgeInset.right = -anEdgeInset.left; // I don't know why this needs to be negative, but that's what works
    }
    if ( scrollerBounds.size.height > innerFrame.size.height )
    {
        anEdgeInset.top = (scrollerBounds.size.height - innerFrame.size.height) / 2;
        anEdgeInset.bottom = -anEdgeInset.top; // I don't know why this needs to be negative, but that's what works
    }
    
    self.zoomeableScrollView.contentOffset = myScrollViewOffset;
    self.zoomeableScrollView.contentInset = anEdgeInset;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    UIView* view = self.theImageView;
    
    CGRect innerFrame = view.frame;
    CGRect scrollerBounds = scrollView.bounds;
    CGPoint myScrollViewOffset = scrollView.contentOffset;
    
    if ( ( innerFrame.size.width < scrollerBounds.size.width ) || ( innerFrame.size.height < scrollerBounds.size.height ) )
    {
        CGFloat tempx = view.center.x - ( scrollerBounds.size.width / 2 );
        CGFloat tempy = view.center.y - ( scrollerBounds.size.height / 2 );
        myScrollViewOffset = CGPointMake( tempx, tempy);
    }
    
    UIEdgeInsets anEdgeInset = { 0, 0, 0, 0};
    if ( scrollerBounds.size.width > innerFrame.size.width )
    {
        anEdgeInset.left = (scrollerBounds.size.width - innerFrame.size.width) / 2;
        anEdgeInset.right = -anEdgeInset.left; // I don't know why this needs to be negative, but that's what works
    }
    if ( scrollerBounds.size.height > innerFrame.size.height )
    {
        anEdgeInset.top = (scrollerBounds.size.height - innerFrame.size.height) / 2;
        anEdgeInset.bottom = -anEdgeInset.top; // I don't know why this needs to be negative, but that's what works
    }
    
    [UIView animateWithDuration:0.3 animations:^{
//        scrollView.contentOffset = myScrollViewOffset;
        scrollView.contentInset = anEdgeInset;
    }];
}

@end
