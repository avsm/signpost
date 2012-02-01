require 'rubygems'
require 'fssm'

module Screen
  def self.clear
    print "\e[2J\e[f"
  end
end

module Tty extend self
  def blue; bold 34; end
  def white; bold 39; end
  def red; underline 31; end
  def green; bold 32; end
  def reset; escape 0; end
  def bold n; escape "1;#{n}" end
  def underline n; escape "4;#{n}" end
  def escape n; "\033[#{n}m" if STDOUT.tty? end
end
 
class Array
  def shell_s
    cp = dup
    first = cp.shift
    cp.map{ |arg| arg.gsub " ", "\\ " }.unshift(first) * " "
  end
end
 
def ohai *args
  puts "#{Tty.blue}==>#{Tty.white} #{args.shell_s}#{Tty.reset}"
end
 
def warn warning
  puts "#{Tty.red}Warning#{Tty.reset}: #{warning.chomp}"
end
 
def error message
  puts "#{Tty.red}ERROR#{Tty.reset}: #{message.chomp}"
end
 
def abort message
  error message
  Kernel.exit 1
end
 
def success message
  puts "#{Tty.green}#{message}#{Tty.reset}"
end

$dir = File.expand_path(File.dirname(__FILE__))
if $dir != Dir.pwd then
  error "ERROR: You should cd into the working directory, otherwise compilation won't work :("
  exit 1
end

def ok_path? path
  if path =~ /.*\.ml$/ then
    if path =~ /_build/ then
      false
    else 
      true
    end
  end
end

def compile_and_run file
  if ok_path? file then
    Screen.clear
    ohai "Compiling"
    output = `ocaml #{$dir}/setup.ml -build`
    contains_error = output =~ /error/i ? true : false
    error "Did not compile cleanly" if contains_error
    output.split("\n").each {|s| contains_error ? puts(s) : ohai(s)}
    if $?.to_i == 0 then
      puts ""
      ohai "Executing program"
      success `#{$dir}/_build/server.byte`
    end
  end
end

def configure file
  if ok_path? file then
    Screen.clear
    ohai "Configuring"
    `ocaml #{$dir}/setup.ml -configure`
  end
end

Screen.clear
ohai "Monitoring changes in #{$dir}"
FSSM.monitor($dir) do
  update do |b, r|
    compile_and_run r
  end

  create do |b, r|
    configure r
    compile_and_run r
  end

  delete do |b, r|
    configure r
    compile_and_run r
  end
end
