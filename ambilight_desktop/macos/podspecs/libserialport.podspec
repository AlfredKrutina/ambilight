# Mirrors CocoaPods trunk libserialport 0.1.1, but pins a real git commit.
# Trunk uses tag libserialport-0.1.1 (annotated); CocoaPods shallow clone then
# warns "is not a commit" and can leave the checkout in a bad state for autogen.sh.

Pod::Spec.new do |s|
  s.name             = 'libserialport'
  s.version          = '0.1.1'
  s.summary          = 'A serial port library.'
  s.description      = <<-DESC
A minimal, cross-platform shared library written in C that is intended to take care of the OS-specific details when writing software that uses serial ports.
                       DESC
  s.homepage         = 'https://sigrok.org/wiki/Libserialport'
  s.license          = { :type => 'LGPL-3.0', :file => 'COPYING' }
  s.author           = 'See AUTHORS file'

  s.source = {
    :git => 'https://github.com/sigrokproject/libserialport.git',
    :commit => '348a6d353af8ac142f68fbf9fe0f4d070448d945'
  }

  s.prepare_command = '((command -v automake && command -v glibtoolize) >/dev/null 2>&1 || ' \
                      '{ echo >&2 \'Please run brew install automake libtool.\'; exit 1; }) && ' \
                      './autogen.sh && ./configure'

  s.platform           = :osx, '10.11'

  s.source_files       = '*.{c,h}'
  s.exclude_files      = ['freebsd.c', 'linux*.c', 'windows.c']
  s.private_header_files = 'libserialport_internal.h'
  s.module_name        = 'libserialport'
  s.compiler_flags     = '-DLIBSERIALPORT_ATBUILD'
  s.requires_arc       = false

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.user_target_xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
