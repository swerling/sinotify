#include <ruby.h>

// includes that are different for ruby 1.8 vs. ruby 1.9
#ifdef RUBY_19
#warning "INCLUDING RUBY19 HEADERS (not really a warning, just for info)"
#include <ruby/io.h>
#else
#warning "INCLUDING RUBY18 HEADERS (not really a warning, just for info) "
#include <rubyio.h>

#endif

#ifdef HAVE_VERSION_H
#include <version.h>
#endif

#ifdef HAVE_LINUX_INOTIFY_H
#include <asm/unistd.h>
#include <linux/inotify.h>
#else
#include "inotify.h"
#include "inotify-syscalls.h"
#endif

#include <sys/syscall.h>
#include <unistd.h>

static inline int inotify_init (void)
{
	return syscall (__NR_inotify_init);
}

static inline int inotify_add_watch (int fd, const char *name, __u32 mask)
{
	return syscall (__NR_inotify_add_watch, fd, name, mask);
}

static inline int inotify_rm_watch (int fd, __u32 wd)
{
	return syscall (__NR_inotify_rm_watch, fd, wd);
}

VALUE rb_cSinotify;
VALUE rb_cNotifier;
VALUE rb_cSinotifyEvent;

int event_check (int fd) {
  struct timeval;
	int r;

	fd_set rfds;
	FD_ZERO(&rfds);
	FD_SET(fd, &rfds);

  // Not using timout anymore
	r = rb_thread_select (fd+1, &rfds, NULL, NULL, NULL);
	return r;
}

static VALUE rb_inotify_event_new(struct inotify_event *event) {
	VALUE retval;
	retval = Data_Wrap_Struct(rb_cSinotifyEvent, NULL, free, event);
	rb_obj_call_init(retval, 0, NULL);
	return retval;
}

/*
 * call-seq: 
 *    Inotify.new => inotify
 *
 */

static VALUE rb_inotify_new(VALUE klass) {
	int *fd;
	VALUE retval;
	fd = malloc(sizeof(int));
	*fd = inotify_init();
	if(*fd < 0) rb_sys_fail("inotify_init()");
	retval = Data_Wrap_Struct(klass, NULL, free, fd);
	rb_obj_call_init(retval, 0, NULL);
	return retval;
}

/*
 * call-seq: 
 *    inotify.add_watch(filename, Inotify::ALL_EVENTS) => watch number
 *
 */

static VALUE rb_inotify_add_watch(VALUE self, VALUE filename, VALUE mask) {
	int *fd, wd;
	Data_Get_Struct(self, int, fd);
	wd = inotify_add_watch(*fd, RSTRING_PTR(filename), NUM2INT(mask));
	if(wd < 0) {
	  rb_sys_fail(RSTRING_PTR(filename));
	}
	return INT2NUM(wd);
}

/*
 * call-seq: 
 *    inotify.rm_watch(filename, wd) => true or raises exception.
 *
 */

static VALUE rb_inotify_rm_watch(VALUE self, VALUE wdnum) {
	int *fd;
	Data_Get_Struct(self, int, fd);
	if(inotify_rm_watch(*fd, NUM2INT(wdnum)) < 0) {
		rb_sys_fail("removing watch");
	}
	return Qtrue;
}

/*
 * call-seq: 
 *    inotify.each_event { |event| ... } 
 *
 */

static VALUE rb_inotify_each_event(VALUE self) {
	int *fd, r;
	struct inotify_event *event, *pevent;
	char buffer[16384];
	size_t buffer_n, event_size;

	Data_Get_Struct(self, int, fd);
	while(1) {
		r = event_check(*fd);
		if(r == 0) {
			continue;
		}
		if((r = read(*fd, buffer, 16384)) < 0) {
			rb_sys_fail("reading event");
		}
		buffer_n = 0;
		while (buffer_n < r) {
			pevent = (struct inotify_event *)&buffer[buffer_n];
			event_size = sizeof(struct inotify_event) + pevent->len;
			event = malloc(event_size);
			memmove(event, pevent, event_size);
			buffer_n += event_size;
			rb_yield(rb_inotify_event_new(event));
		}
	}
	return Qnil;
}

/*
 * call-seq: 
 *    inotify.close => nil
 *
 */

static VALUE rb_inotify_close(VALUE self) {
	int *fd;
	Data_Get_Struct(self, int, fd);
	if(close(*fd) != 0) {
		rb_sys_fail("closing inotify");
	}
	return Qnil;
}

/*
 * call-seq: 
 *    inotify_event.inspect => "<Sinotify::PrimEvent name=foo mask=0xdeadbeef wd=123>"
 *
 */

/*
static VALUE rb_inotify_event_inspect(VALUE self) {
	struct inotify_event *event;
	int len, pf;
	char buf[1024]; 
	Data_Get_Struct(self, struct inotify_event, event);
	len = event->len;
	/ * TODO: Check for string getting truncated * /
	pf = snprintf(buf, 1024, "<Sinotify::PrimEvent name=%s mask=%ld wd=%d>", 
	    event->name, event->mask, event->wd);
	return rb_str_new2(buf);
}
*/

/*
 * call-seq: 
 *    inotify_event.name => name or nil
 *
 */

static VALUE rb_inotify_event_name(VALUE self) {
	struct inotify_event *event;
	Data_Get_Struct(self, struct inotify_event, event);
	if(event->len) {
		return rb_str_new2(event->name);
	} else {
		return Qnil;
	}
}

/*
 * call-seq: 
 *    inotify_event.wd => watch descriptor
 *
 */

static VALUE rb_inotify_event_wd(VALUE self) {
	struct inotify_event *event;
	Data_Get_Struct(self, struct inotify_event, event);
	return INT2NUM(event->wd);
}

/*
 * call-seq: 
 *    inotify_event.mask => mask as defined by linux inotify lib 
 *    (see 'man inotify' section on inotify events)
 *
 */

static VALUE rb_inotify_event_mask(VALUE self) {
	struct inotify_event *event;
	Data_Get_Struct(self, struct inotify_event, event);
	return LONG2NUM(event->mask);
}

void Init_sinotify () {
	rb_cSinotify = rb_define_module("Sinotify");

  // The Inotify class
  //rb_cNotifier = rb_define_class("Sinotify", rb_cObject);
	rb_cNotifier = rb_define_class_under(rb_cSinotify, "PrimNotifier", rb_cObject);

  // following inotify masks taken from inotify lib, see 'man inotify', section
	rb_const_set(rb_cSinotify, rb_intern("ACCESS"), INT2NUM(IN_ACCESS));
	rb_const_set(rb_cSinotify, rb_intern("MODIFY"), INT2NUM(IN_MODIFY));
	rb_const_set(rb_cSinotify, rb_intern("ATTRIB"), INT2NUM(IN_ATTRIB));
	rb_const_set(rb_cSinotify, rb_intern("CLOSE_WRITE"), INT2NUM(IN_CLOSE_WRITE));
	rb_const_set(rb_cSinotify, rb_intern("CLOSE_NOWRITE"), INT2NUM(IN_CLOSE_NOWRITE));
	rb_const_set(rb_cSinotify, rb_intern("OPEN"), INT2NUM(IN_OPEN));
	rb_const_set(rb_cSinotify, rb_intern("MOVED_FROM"), INT2NUM(IN_MOVED_FROM));
	rb_const_set(rb_cSinotify, rb_intern("MOVED_TO"), INT2NUM(IN_MOVED_TO));
	rb_const_set(rb_cSinotify, rb_intern("CREATE"), INT2NUM(IN_CREATE));
	rb_const_set(rb_cSinotify, rb_intern("DELETE"), INT2NUM(IN_DELETE));
	rb_const_set(rb_cSinotify, rb_intern("DELETE_SELF"), INT2NUM(IN_DELETE_SELF));
	rb_const_set(rb_cSinotify, rb_intern("MOVE_SELF"), INT2NUM(IN_MOVE_SELF));
	rb_const_set(rb_cSinotify, rb_intern("UNMOUNT"), INT2NUM(IN_UNMOUNT));
	rb_const_set(rb_cSinotify, rb_intern("Q_OVERFLOW"), INT2NUM(IN_Q_OVERFLOW));
	rb_const_set(rb_cSinotify, rb_intern("IGNORED"), INT2NUM(IN_IGNORED));
	rb_const_set(rb_cSinotify, rb_intern("CLOSE"), INT2NUM(IN_CLOSE));
	rb_const_set(rb_cSinotify, rb_intern("MOVE"), INT2NUM(IN_MOVE));
	rb_const_set(rb_cSinotify, rb_intern("ONLYDIR"), INT2NUM(IN_ONLYDIR));
	rb_const_set(rb_cSinotify, rb_intern("DONT_FOLLOW"), INT2NUM(IN_DONT_FOLLOW));
	rb_const_set(rb_cSinotify, rb_intern("MASK_ADD"), INT2NUM(IN_MASK_ADD));
	rb_const_set(rb_cSinotify, rb_intern("ISDIR"), INT2NUM(IN_ISDIR));
	rb_const_set(rb_cSinotify, rb_intern("ONESHOT"), INT2NUM(IN_ONESHOT));
	rb_const_set(rb_cSinotify, rb_intern("ALL_EVENTS"), INT2NUM(IN_ALL_EVENTS));

	rb_define_singleton_method(rb_cNotifier, "new", rb_inotify_new, 0);
	rb_define_method(rb_cNotifier, "add_watch", rb_inotify_add_watch, 2);
	rb_define_method(rb_cNotifier, "rm_watch", rb_inotify_rm_watch, 1);
	rb_define_method(rb_cNotifier, "each_event", rb_inotify_each_event, 0);
	rb_define_method(rb_cNotifier, "close", rb_inotify_close, 0);


  // The Sinotify::PrimEvent class
  // (todo: get rid of inspect, move to ruby)
	rb_cSinotifyEvent = rb_define_class_under(rb_cSinotify, "PrimEvent", rb_cObject);
	rb_define_method(rb_cSinotifyEvent, "prim_name", rb_inotify_event_name, 0);
	rb_define_method(rb_cSinotifyEvent, "prim_wd", rb_inotify_event_wd, 0);
	rb_define_method(rb_cSinotifyEvent, "prim_mask", rb_inotify_event_mask, 0);

}
