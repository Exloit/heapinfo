require 'codeclimate-test-reporter'
require 'simplecov'
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, CodeClimate::TestReporter::Formatter]
)
SimpleCov.start do
  add_filter '/spec/'
end

require 'heapinfo/helper'

RSpec.configure do |config|
  module Victims
    @victims = []
    def self.push(arg)
      @victims.push(arg)
      arg
    end

    def self.killall
      @victims.each do |victim|
        `killall #{victim}`
        FileUtils.rm(victim)
      end
      @victims = []
    end
  end

  config.before(:all) do
    HeapInfo::Helper.toggle_color(on: false)
    # return the absolute path of exectuable file.
    @compile_and_run = lambda do |bit: 64, lib_ver: '2.23', flags: ''|
      victim = HeapInfo::Helper.tempfile('victim')
      cwd = File.expand_path('../files', __FILE__)
      `cd #{cwd} && make victim OUTFILE=#{victim} BIT=#{bit} LIB_VER=#{lib_ver} CFLAGS=#{flags} 2>&1 > /dev/null`
      pid = fork
      # run without ASLR
      exec "setarch `uname -m` -R /bin/sh -c #{victim}" if pid.nil?
      loop until `pidof #{victim}` != ''
      Victims.push(victim)
    end
    @all_libs_heapinfo = lambda do |bit|
      Dir.glob(File.join(__dir__, 'files', 'libraries', 'libc-*')).map do |dir|
        ver = File.basename(dir).sub('libc-', '')
        HeapInfo::Process.new(@compile_and_run.call(bit: bit, lib_ver: ver))
      end
    end
  end

  config.after(:all) do
    Victims.killall
  end
end
