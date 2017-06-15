#!/usr/bin/env ruby
require 'digest'                # work with digests
require 'fileutils'             # advanced file utils: FileUtils
require 'mkmf'                  # system utils: find_executable
require 'open-uri'              # easily read HTTP
require 'optparse'              # cmd line options: OptionParser
require 'ostruct'               # OpenStruct
require 'open3'                 # Better system commands
require 'rubygems/package'      # tar
require 'yaml'                  # YAML

# Gems that should already be installed
begin
  require 'colorize'            # color output: colorize
  require 'filesize'            # human readable file sizes: Filesize
  require 'net/ssh'             # ssh integration: Net::SSH
  require 'net/scp'             # scp integration: Net::SCP
rescue Exception => e
  mod = e.message.split(' ').last.sub('/', '-')
  !puts("Error: install missing module with 'sudo gem install --no-user-install #{mod}'") and exit
end

class Reduce

  def initialize
    puts("Hello init")
  end

  def build()
    puts("Hello build")
  end
end

#-------------------------------------------------------------------------------
# Main entry point
#-------------------------------------------------------------------------------
if __FILE__ == $0
  opts = {}
  app = 'reduce'

  # Configure command line options
  #-------------------------------------------------------------------------------
  help = <<HELP
  Commands available for use:
      build                            Build ISO components

  see './#{app}.rb COMMAND --help' for specific command info
HELP

  optparser = OptionParser.new do |parser|
    banner = "#{app}\n#{'-' * 80}\n".colorize(:yellow)
    examples = "Examples:\n".colorize(:green)
    examples += "Build: sudo ./#{app}.rb clean build --iso-full\n".colorize(:green)
    parser.banner = "#{banner}#{examples}\nUsage: ./#{app}.rb commands [options]"
    parser.on('-h', '--help', 'Print command/options help') {|x| !puts(parser) and exit }
    parser.separator(help)
  end

  optparser_cmds = {
    'build' => [OptionParser.new{|parser|
      parser.banner = "Usage: ./#{app}.rb build [options]"
      parser.on('--iso', "Build USB bootable ISO from existing '_iso_' workspace") {|x| opts[:iso] = x}
    }]
  }

  # Evaluate command line args
  ARGV.clear and ARGV << '-h' if ARGV.empty? or not optparser_cmds[ARGV[0]]
  optparser.order!
  cmds = ARGV.select{|x| not x.include?('--')}
  ARGV.reject!{|x| not x.include?('--')}
  cmds.each{|x| !puts("Error: invalid command '#{x}'".colorize(:red)) and exit unless optparser_cmds[x]}
  cmds.each do |cmd|
    begin
      opts[cmd.to_sym] = true
      optparser_cmds[cmd].first.order!
    rescue OptionParser::InvalidOption => e

      # Re-set chain options
      if optparser_cmds[cmd].last.any?{|x| e.to_s.include?(x)}
        optparser_cmds[cmd].last.select{|x| e.to_s.include?(x)}.each{|x|
          ARGV << e.to_s[/(--#{x}.*)/, 1]}
      # Print help
      else
        puts("Error: #{e}".colorize(:red))
        !puts(optparser_cmds[cmd].first.help) and exit
      end
    end
  end

  # Check required options
  if ARGV.any?
    !puts("Error: unhandled arguments #{ARGV}".colorize(:red)) and exit
  end

  #-------------------------------------------------------------------------------
  # Execute application
  #-------------------------------------------------------------------------------
  reduce = Reduce.new

  # Process 'build' command
  if opts[:build]
    help = nil
    !puts(help.colorize(:red)) and !puts(optparser_cmds['build'].help) and exit if help

    reduce.build
  end
end

# vim: ft=ruby:ts=2:sw=2:sts=2