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
  end

  def build()
    puts("Hello build")
  end

  # Insert into a file
  # Location of insert is determined by the given regex and offset.
  # Append is used if no regex is given.
  # Params:
  # +file+:: path of file to modify
  # +values+:: string or list of string values to insert
  # +regex+:: regular expression for location, not used if offset is nil
  # +offset+:: offset the insert location by this amount
  # +returns+:: true if a change was made to the file
  def file_insert(file, values, regex:nil, offset:1)
    return false if not values or values.empty?

    change = false
    values = [values] if values.is_a?(String)
    FileUtils.touch(file) if not File.exist?(file)

    begin
      lines = nil
      File.open(file, 'r+') do |f|
        lines = f.readlines

        # Match regex for insert location
        regex = Regexp.new(regex) if regex.is_a?(String)
        i = regex ? lines.index{|x| x =~ regex} : lines.size - 1
        return false if not i
        i += offset

        # Insert at offset
        values.each{|x|
          lines.insert(i, x) and i += 1
          change = true
        }

        # Truncate then write out new content
        f.seek(0)
        f.truncate(0)
        f.puts(lines)
      end
    rescue
      # Revert back to the original incase of failure
      File.open(file, 'w'){|f| f.puts(lines)} if lines
      raise
    end

    return change
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
