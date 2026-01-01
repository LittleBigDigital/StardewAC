#include "RunApp.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <pthread.h>
#include <unistd.h>
#include <stdbool.h>
#include <signal.h>
#include <stdio.h>

#ifndef kVK_RightShift
#define kVK_RightShift 0x3C
#endif
#ifndef kVK_ANSI_R
#define kVK_ANSI_R 0x0F
#endif
#ifndef kVK_ForwardDelete
#define kVK_ForwardDelete 0x75
#endif

static volatile bool gMiddleMouseDown = false;
static pthread_t gWorkerThread;
static volatile bool gWorkerRunning = false;
static const CFTimeInterval kRepeatInterval = 0.2; // 200ms

static CFMachPortRef gEventTap = NULL;
static CFRunLoopSourceRef gRunLoopSource = NULL;
static CFRunLoopRef gRunLoop = NULL;

static volatile sig_atomic_t gShouldQuit = 0;

//This code will "press" R-Shift + R + Delete key
static void cancelAnimation(void){
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef keyEventRShiftDown = CGEventCreateKeyboardEvent(source, kVK_RightShift, true);
    CGEventRef keyEventRDown = CGEventCreateKeyboardEvent(source, kVK_ANSI_R, true);
    CGEventRef keyEventDeleteDown = CGEventCreateKeyboardEvent(source, kVK_ForwardDelete, true);
    CGEventRef keyEventRShiftUp = CGEventCreateKeyboardEvent(source, kVK_RightShift, false);
    CGEventRef keyEventRUp = CGEventCreateKeyboardEvent(source, kVK_ANSI_R, false);
    CGEventRef keyEventDeleteUp = CGEventCreateKeyboardEvent(source, kVK_ForwardDelete, false);
    CGEventPost(kCGSessionEventTap, keyEventRShiftDown);
    CGEventPost(kCGSessionEventTap, keyEventRDown);
    CGEventPost(kCGSessionEventTap, keyEventDeleteDown);
    usleep(20000);
    CGEventPost(kCGSessionEventTap, keyEventRShiftUp);
    CGEventPost(kCGSessionEventTap, keyEventRUp);
    CGEventPost(kCGSessionEventTap, keyEventDeleteUp);
    CFRelease(keyEventRShiftDown);
    CFRelease(keyEventRDown);
    CFRelease(keyEventDeleteDown);
    CFRelease(keyEventRShiftUp);
    CFRelease(keyEventRUp);
    CFRelease(keyEventDeleteUp);
    CFRelease(source);
}

static void synthesizeLeftClick(void) {
    CGEventRef current = CGEventCreate(NULL);
    CGPoint location = CGEventGetLocation(current);
    CFRelease(current);
    CGEventRef mouseDown = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, location, kCGMouseButtonLeft);
    CGEventRef mouseUp = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, location, kCGMouseButtonLeft);
    if (mouseDown) CGEventPost(kCGHIDEventTap, mouseDown);
    usleep(20000);
    if (mouseUp) CGEventPost(kCGHIDEventTap, mouseUp);
    if (mouseDown) CFRelease(mouseDown);
    if (mouseUp) CFRelease(mouseUp);
}

static void *MiddleButtonWorker(void *arg) {
    (void)arg;
    while (1) {
        synthesizeLeftClick();
        const useconds_t delayUs = (useconds_t)(kRepeatInterval * 1000000.0);
        usleep(delayUs);
        cancelAnimation();
        if (!gMiddleMouseDown || gShouldQuit) {
            break;
        }
    }
    gWorkerRunning = false;
    return NULL;
}

static CGEventRef CGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy; (void)refcon;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (gEventTap) CGEventTapEnable(gEventTap, true);
        return event;
    }
    if (type != kCGEventOtherMouseDown && type != kCGEventOtherMouseUp) {
        return event;
    }
    if (type == kCGEventOtherMouseDown) {
        gMiddleMouseDown = true;
        if (!gWorkerRunning) {
            gWorkerRunning = true;
            pthread_create(&gWorkerThread, NULL, MiddleButtonWorker, NULL);
            pthread_detach(gWorkerThread);
        }
    } else if (type == kCGEventOtherMouseUp) {
        gMiddleMouseDown = false;
    }
    return event;
}

static void startEventTap(void) {
    if (gEventTap) return;
    CGEventMask eventMask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);
    gEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, CGEventCallback, NULL);
    if (!gEventTap) {
        fprintf(stderr, "Accessibility permissions not granted. Enable in System Settings → Privacy & Security → Accessibility.\n");
        // Do not exit; allow caller to decide. Just return without setting quit flag.
        return;
    }
    gRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gEventTap, 0);
    gRunLoop = CFRunLoopGetCurrent();
    CFRetain(gRunLoop);
    CFRunLoopAddSource(gRunLoop, gRunLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(gEventTap, true);
}

static void stopEventTapInternal(void) {
    if (gEventTap) {
        CGEventTapEnable(gEventTap, false);
    }
    if (gRunLoopSource) {
        if (gRunLoop) CFRunLoopRemoveSource(gRunLoop, gRunLoopSource, kCFRunLoopCommonModes);
        CFRelease(gRunLoopSource);
        gRunLoopSource = NULL;
    }
    if (gEventTap) {
        CFRelease(gEventTap);
        gEventTap = NULL;
    }
    if (gRunLoop) {
        CFRelease(gRunLoop);
        gRunLoop = NULL;
    }
}

void runApp(void) {
    gShouldQuit = 0;
    gMiddleMouseDown = false;

    startEventTap();
    if (gShouldQuit) {
        // Failed to start; clean any partial state
        stopEventTapInternal();
        return;
    }

    // Run the CFRunLoop until stopApp() is called
    while (!gShouldQuit) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
    }

    // Clean up
    gMiddleMouseDown = false;
    stopEventTapInternal();
    // Give worker thread a moment to observe gMiddleMouseDown = false
    usleep(50000);
}

void stopApp(void) {
    gShouldQuit = 1;
}

bool isAccessibilityEnabled(void) {
    // Returns true if the app has Accessibility permissions
    return AXIsProcessTrusted();
}
