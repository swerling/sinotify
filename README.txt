sinotify
    by Steven Swerling
    http://tab-a.slot-z.net

== DESCRIPTION:

What is inotify: 
  on linux, type 'man inotify'
  on others, 'google inotify' 

The 's' in 'sinotify' in fact stands for 'suck:' 
  http://www.kernel.org/pub/linux/kernel/people/rml/inotify/README

xxVersion of ruby-inotify tweaked to:

Inotify is a linux library for sending event notification when something on the file system
has changed. (see 'man inotify' for detail). This is a wrapper for the linux inotify library
for ruby. This package derived from aredridel's package (http://raa.ruby-lang.org/project/ruby-inotify/).
Differences from aredridel's package:

 1. Use standard event pattern for notfication (rather than synchronous loop)
 2. Ability to create a recursive watch (in otherwords, specify a directory
    and receive notification on any changes w/in that directory or its children)
 3. The suggestion made by Paul Boon for making the event_check thread more well
    behaved (see http://www.mindbucket.com/2009/02/24/ruby-daemons-verifying-good-behavior/)

The name 'sinotify' is a concatenation of 'sinai' and 'inotify'. This project was factored of and designed to 
support 'sinai'. 

== FEATURES/PROBLEMS:

* Not tested with ruby 1.9.

== SYNOPSIS:

  TODO

== REQUIREMENTS:

* linux inotify dev libs

== INSTALL:

* sudo gem install sinotify

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIXME (different license?)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
