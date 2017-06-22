#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'ostruct'

require_relative 'erb'

module Edit

  # Edit files driven by 'changes'
  # Due to the nature of 'changes' see ../README.md the file implicated in the change
  # should be ignored in favor of the 'file' being passed in which should be properly
  # resolved at this point. Again all templating should have already been resolve as
  # well before this call.
  # Params:
  # +change+:: change yaml to execute
  # +file+:: file to work with
  # +returns+:: true on change
  def file(change, file)
    k = OpenStruct.new({after: 'after', append: 'append', regex: 'regex',
      value: 'value', values: 'values'})

    changed = false
    values = change[k.value] ? [change[k.value]] : change[k.values]
    FileUtils.mkdir_p(File.dirname(file)) if not File.exist?(File.dirname(file))

    if not File.exist?(file)
      changed |= Edit.insert(file, values)
    else
      append = change[k.append]
      data = File.read(file, 'rb')
      digest = Digest::MD5.hexdigest(data)
  
      # Check if the changes have already been made
      already = data =~ Regexp.new(Regexp.quote(values.first))
      already = values.all?{|y| data =~ Regexp.new(Regexp.quote(y))} if values.size > 1
 
      # Regex replacements
      if not append
        Edit.replace(file, change[k.regex], values.first)

      # File insert/appends
      elsif not already
        offset = append == true ? nil : append == k.after ? 1 : 0
        Edit.insert(file, values, regex:change[k.regex], offset:offset)
      end
  
      changed |= (digest != Digest::MD5.hexdigest(File.read(file, 'rb')))
    end

    return changed
  end
  module_function(:file)

  # Replace in file
  # Params:
  # +file+:: file to modify
  # +regex+:: regular expression match on
  # +value+:: regulare expression to replace with
  # +returns+:: true on change
  def replace(file, regex, value)
    changed = false
    begin
      data = nil
      File.open(file, 'r+') do |f|
        data = f.read
        lines = data.split("\n")

        # Search replace
        regex = Regexp.new(regex) if regex.is_a?(String)
        lines.each{|x| x.gsub!(regex, value)}
        lines.each{|x| x.gsub!(/\r\n/, "\n")}

        # Determine if file changed
        changed = Digest::MD5.hexdigest(data) != Digest::MD5.hexdigest(lines * "\n")

        # Truncate then write out new content
        f.seek(0)
        f.truncate(0)
        f.puts(lines)
      end
    rescue
      # Revert back to the original incase of failure
      File.open(file, 'w'){|f| f << data} if data
      raise
    end

    return changed
  end
  module_function(:replace)

  # Insert into a file
  # Location of insert is determined by the given regex and offset.
  # Append is used if no regex is given.
  # Params:
  # +file+:: path of file to modify
  # +values+:: string or list of string values to insert
  # +regex+:: regular expression for location, not used if offset is nil
  # +offset+:: offset insert location by this amount for regexs
  # +returns+:: true if a change was made to the file
  def insert(file, values, regex:nil, offset:1)
    return false if not values or values.empty?

    changed = false
    values = [values] if values.is_a?(String)
    FileUtils.touch(file) if not File.exist?(file)

    begin
      data = nil
      File.open(file, 'r+') do |f|
        data = f.read
        lines = data.split("\n")

        # Match regex for insert location
        regex = Regexp.new(regex) if regex.is_a?(String)
        i = regex ? lines.index{|x| x =~ regex} : lines.size
        return false if not i
        i += offset if regex and offset

        # Insert at offset
        values.each{|x|
          lines.insert(i, x) and i += 1
          changed = true
        }

        # Truncate then write out new content
        f.seek(0)
        f.truncate(0)
        f.puts(lines)
      end
    rescue
      # Revert back to the original incase of failure
      File.open(file, 'w'){|f| f << data} if data
      raise
    end

    return changed
  end
  module_function(:insert)

  # Resolve template
  # Params:
  # +file+:: file to resolve templates for
  # +vars+:: hash or ostruct templating variables to use while resolving
  # +returns+:: true on change
  def resolve(file, vars)
    changed = false

    begin
      data = nil
      File.open(file, 'r+') do |f|
        data = f.read

        # Resolve templates
        _data = data.erb(vars)

        # Determine if file changed
        changed = Digest::MD5.hexdigest(data) != Digest::MD5.hexdigest(_data)

        # Truncate then write out new content
        if changed
          f.seek(0)
          f.truncate(0)
          f.puts(_data)
        end
      end
    rescue
      # Revert back to the original incase of failure
      File.open(file, 'w'){|f| f << data} if data
      raise
    end

    return changed
  end
  module_function(:resolve)
end

# vim: ft=ruby:ts=2:sw=2:sts=2
