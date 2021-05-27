#include <X11/Xlib.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

#define SPACE_KEYSYM 0x20
Display *init(void) {
  Display *display = XOpenDisplay(NULL);
  if (display) {
    XKeysymToKeycode(display, SPACE_KEYSYM);
    return display;
  }
  exit(EXIT_FAILURE);
}
void emit(XMappingEvent *mapping) {
  if (mapping->request == MappingKeyboard) {
    kill(getppid(), SIGUSR1);
  }
  XRefreshKeyboardMapping(mapping);
}
void loop(Display *display) {
  XEvent event;
  while (1) {
    XNextEvent(display, &event);
    if (event.type == MappingNotify) {
      emit((XMappingEvent *)&event);
    }
  }
}
int main(int argc, char **argv) {
  loop(init());
  exit(EXIT_SUCCESS);
}
