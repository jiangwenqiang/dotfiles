#include <stdio.h>
#include <stdlib.h>
#include <Carbon/Carbon.h>
#include <Foundation/Foundation.h>

int main(int argc, char *argv[]) {
  id pool = [NSAutoreleasePool new];

  if (argc == 1) {
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
    NSString *prop = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    printf("%s",[prop UTF8String]);
    CFRelease(inputSource);
  }

  if (argc == 2) {
    const char* aim = argv[1];
    NSString *inputSourceID = [NSString stringWithUTF8String:aim];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:inputSourceID
                                                           forKey:(NSString *)kTISPropertyInputSourceID];
    NSArray *inputSources = [(NSArray *)TISCreateInputSourceList((CFDictionaryRef)properties, true) autorelease];
    if ([inputSources count] == 0) {
      fprintf(stderr,"Specified input source \"%s\" not found\n", aim);
      [pool release];
      return 1;
    }
    TISInputSourceRef inputSource = (TISInputSourceRef)[inputSources objectAtIndex:0];
    TISSelectInputSource(inputSource);
  }

  [pool release];
  return 0;
}
