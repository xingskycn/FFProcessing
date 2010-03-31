//
//  FFProcessing.m
//  FFPlayer
//
//  Created by Gabriel Handford on 3/21/10.
//  Copyright 2010. All rights reserved.
//

#import "FFProcessing.h"
#import "FFDefines.h"
#import "FFUtils.h"

@implementation FFProcessing

- (void)dealloc {
  [self close];
  [super dealloc];
}

- (BOOL)openSourceURL:(NSURL *)URL path:(NSString *)path format:(NSString *)format error:(NSError **)error {
  _decoder = [[FFDecoder alloc] init];
  
  if (![_decoder openWithURL:URL format:format error:error]) {
    return NO;
  }
  
  _decoderFrame = avcodec_alloc_frame();
  if (_decoderFrame == NULL) {
    FFSetError(error, FFErrorCodeAllocateFrame, @"Couldn't allocate frame");
    return NO;
  }
  
  //FFDebug(@"Video bit rate: %d", [_decoder videoBitRate]);
  
  _encoder = [[FFEncoder alloc] initWithWidth:[_decoder width] 
                                       height:[_decoder height]
                                  pixelFormat:[_decoder pixelFormat]
                                 videoBitRate:400000];

  if (![_encoder open:path error:error])
    return NO;
  
  return YES;
}

- (BOOL)process:(NSError **)error {
  NSAssert(_decoder, @"No decoder, forgot to open?");
  NSAssert(_encoder, @"No encoder, forgot to open?");

  if (!error) {
    NSError *processError = nil;
    error = &processError;
  }

  if (![_encoder writeHeader:error]) 
    return NO;
  
  while (YES) {
    *error = nil;
    
    AVPacket packet;
    if (![_decoder readFrame:&packet error:error]) {
      if (*error) {
        FFDebug(@"Read frame error");
        break;
      }
      continue;
    }
    
    if (![_decoder decodeFrame:_decoderFrame packet:&packet error:error]) {
      if (*error) {
        FFDebug(@"Decode error");
        break;
      }      
      continue;
    }
    
    if (!error) {
      if (_decoderFrame->pict_type == FF_I_TYPE) {
        FFDebug(@"Packet, pts=%lld, dts=%lld", packet.pts, packet.dts);

        FFDebug(@"Frame, key_frame=%d, pict_type=%@", 
                _decoderFrame->key_frame, NSStringFromAVFramePictType(_decoderFrame->pict_type));
      }
    }
    
    AVFrame *picture = FFPictureCreate([_decoder pixelFormat], [_decoder width], [_decoder height]);
    av_picture_copy((AVPicture *)picture, (AVPicture *)_decoderFrame, [_decoder pixelFormat], [_decoder width], [_decoder height]);
        
    int bytesEncoded = [_encoder encodeVideoFrame:picture error:error];
    if (bytesEncoded < 0) break;
    
    // Mosh!
    if ([_encoder videoCodecContext]->coded_frame->key_frame) {      
      continue;     
    }
    
    // If bytesEncoded is zero, there was buffering
    if (bytesEncoded > 0) {
      if (![_encoder writeVideoBuffer:error]) break;
    }
    
    av_free_packet(&packet);
  }
  
  if (![_encoder writeTrailer:error]) return NO;
  
  return YES;
}
     
- (void)close {
  if (_decoderFrame != NULL) {
    av_free(_decoderFrame);
    _decoderFrame = NULL;
  }
  [_decoder release];
  _decoder = nil;
  
  [_encoder release];
  _encoder = nil;
}

@end
