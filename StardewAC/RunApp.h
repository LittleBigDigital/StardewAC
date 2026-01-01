#ifndef RUNAPP_H
#define RUNAPP_H

#ifdef __cplusplus
extern "C" {
#endif

// Starts the event tap and runs its loop on the calling thread until stopApp() is called.
// This function is blocking; call it from a background thread.
void runApp(void);

// Signals the run loop to stop and tears down the event tap.
void stopApp(void);

#ifdef __cplusplus
}
#endif

#endif /* RUNAPP_H */
