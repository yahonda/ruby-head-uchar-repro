# ruby-head UChar / OnigUChar collision reproduction

Since ["Make T_REGEXP embedded"](https://github.com/ruby/ruby/pull/17671)
([`b58a6024a0`](https://github.com/ruby/ruby/commit/b58a6024a07ab0bf7f45d1a17fe216822125444a)),
`include/ruby/internal/core/rregexp.h` includes `ruby/onigmo.h` to get the
complete definition of `struct re_pattern_buffer`. As a result, every C
extension that includes `ruby.h` now gets onigmo.h's

```c
#ifndef ONIG_ESCAPE_UCHAR_COLLISION
# define UChar OnigUChar
#endif
```

macro, because extensions do not define `ONIG_ESCAPE_UCHAR_COLLISION`.

If ICU headers are included after `ruby.h` — directly, or transitively through
libxml2 built with ICU (for example Ubuntu 24.04's libxml2 2.9.14, whose public
`libxml/encoding.h` includes `<unicode/ucnv.h>`) — ICU's `typedef uint16_t UChar;`
expands to `typedef uint16_t OnigUChar;` and compilation fails.

## Reproduce

```
docker build .
```

The build fails on the final step while compiling `repro.c`
(`#include <ruby.h>` followed by `#include <unicode/uchar.h>`):

```
compiling repro.c
In file included from /usr/local/include/ruby-4.1.0+4/ruby/internal/core/rregexp.h:30,
                 from /usr/local/include/ruby-4.1.0+4/ruby/internal/core.h:31,
                 from /usr/local/include/ruby-4.1.0+4/ruby/ruby.h:29,
                 from /usr/local/include/ruby-4.1.0+4/ruby.h:38,
                 from repro.c:1:
/usr/local/include/ruby-4.1.0+4/ruby/onigmo.h:76:16: error: conflicting types for 'OnigUChar'; have 'uint16_t' {aka 'short unsigned int'}
   76 | # define UChar OnigUChar
      |                ^~~~~~~~~
/usr/local/include/ruby-4.1.0+4/ruby/onigmo.h:79:24: note: previous declaration of 'OnigUChar' with type 'OnigUChar' {aka 'unsigned char'}
   79 | typedef unsigned char  OnigUChar;
      |                        ^~~~~~~~~
make: *** [Makefile:251: repro.o] Error 1
```

The `Dockerfile` is pinned by digest to the exact `rubylang/ruby:master` image
used by the failed Rails nightly build, so the environment is fixed even after
ruby master changes:

- `ruby 4.1.0dev (2026-07-06T16:40:46Z master 53443163ec)`
- gcc 13.3.0, ICU 74.2, Ubuntu 24.04

## Reproduce without Docker

Docker is only used here to pin a ruby master snapshot that still contains the
change; the failure itself is not tied to Docker or to a particular OS. It
reproduces on any system once the relevant package versions line up, namely a
ruby master build that includes `b58a6024a0` together with ICU development
headers:

```
apt-get install -y gcc make libicu-dev
ruby extconf.rb && make
```

The same compile error appears. These are the versions this was verified with
(the set the `Dockerfile` pins):

- Ubuntu 24.04
- `ruby 4.1.0dev (2026-07-06T16:40:46Z master 53443163ec)`
- gcc 13.3.0
- ICU 74.2 (`libicu-dev` 74.2-1ubuntu3.1)

## Workaround

Compiling with `-DONIG_ESCAPE_UCHAR_COLLISION` stops onigmo.h from defining the
`UChar` macro and lets the file compile. Existing gems cannot be expected to add
that define, though.

## Notes

- libxml2 >= 2.12 no longer includes ICU headers from its public headers, so the
  original libxml-ruby failure only occurs on distributions shipping older
  libxml2 (such as Ubuntu 24.04). The reproduction here does not involve libxml2
  and fails on any system with ICU headers installed.
- Real-world impact: `gem install libxml-ruby` fails on ruby-head, blocking the
  Rails ruby-head CI —
  [rails-nightly build 4522](https://buildkite.com/rails/rails-nightly/builds/4522#019f393b-4212-453f-8f4f-c1a538af23e5).
  A temporary CI workaround is
  [rails/buildkite-config#187](https://github.com/rails/buildkite-config/pull/187).
