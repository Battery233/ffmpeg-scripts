# FFmpeg scripts

Here are some scripts for processing images/videos using ffmpeg and imagemagick

- *createVideoWithAlphaChannel* takes PNG sequential frames and generates an mp4 video with Alpha channel on the left & RGB channel on the right. Output FPS and bit rate can be specified. This type of video is often used in mobile apps to create a layer of effects.

  To run: **./createVideoWithAlphaChannel.sh demo.zip \<FPS\> \<bit rate\> \<ffmpeg bin location\>**
  
  Demo:
  
  Sequential frames input:
  
  <img src="img\Frames.jpg" style="zoom: 33%;" /> 
  
  Video output:
  
  <img src="img\Demo.jpg" style="zoom: 33%;" /> 
