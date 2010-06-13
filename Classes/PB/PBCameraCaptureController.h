//
//  PBCameraCaptureController.h
//  FFProcessing
//
//  Created by Gabriel Handford on 5/7/10.
//  Copyright 2010. All rights reserved.
//

#import "FFAVCaptureSessionReader.h"

#import "FFPlayerView.h"
#import "FFFilter.h"

@interface PBCameraCaptureController : UIViewController {
  FFPlayerView *_playerView;
}

- (void)setFilter:(id<FFFilter>)filter;

@end
