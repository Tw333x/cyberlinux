#!/usr/bin/env ruby
#MIT License
#Copyright (c) 2017 phR0ze
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

require 'minitest/autorun'
require 'ostruct'

require_relative '../lib/change'
require_relative '../lib/fedit'
require_relative '../lib/sys'

class TestApply < Minitest::Test

  def setup
    @file = 'foo'
    @ctx = OpenStruct.new({
      root: '/de',
      vars: {
        var1: 'var1',
        file_var: '/foo'
      },
      changes: {
        'config-foobar1' => [
          { 'edit' => '/foo', 'append' => 'after', 'value' => 'bar', 'regex' => '/bob/' }
        ],
        'config-foobar2' => [
          { 'edit' => '<%= file_var %>', 'append' => 'after', 'value' => 'bar', 'regex' => '/bob/' }
        ]
      }
    })
  end

  def test_apply_with_exec
    ctx = OpenStruct.new({ root: '.', vars: { var1: 'var1', file_var: '/foo' } })

    Sys.stub(:puts, nil){
      refute(Change.apply({'exec' => 'touch /foo'}, ctx))
      assert(File.exist?('foo'))
      refute(Change.apply({'exec' => 'rm /foo'}, ctx))
      refute(File.exist?('foo'))
    }
  end

  def test_apply_with_templating_reference
    change = { 'apply' => 'config-foobar2'}
    change_insert_helper(change, 1)
  end

  def test_apply_with_templating
    change = { 'edit' => '<%= file_var %>', 'append' => 'after', 'value' => 'bar', 'regex' => '/bob/' }
    change_insert_helper(change, 1)
  end

  def test_apply_with_resolve
    change = { 'resolve' => '/foo' }

    assert_args = ->(file, vars){
      assert_equal(File.join(@ctx.root, @file), file)
      assert_equal(@ctx.vars, vars)
      true
    }

    Fedit.stub(:resolve, assert_args){
      assert(Change.apply(change, @ctx))
    }
  end

  def test_apply_with_apply_reference_fail
    change = { 'apply' => 'config-bar' }
    assert_raises(NoMethodError){change_insert_helper(change, 1)}
  end

  def test_apply_with_apply_reference_success
    change = { 'apply' => 'config-foobar1' }
    change_insert_helper(change, 1)
  end

  def test_apply_file_doesnt_exist
    change = { 'edit' => '/foo', 'value' => 'bar' }

    Change.stub(:puts, nil){
      FileUtils.stub(:mkdir_p, true, @file){
        File.stub(:exist?, false, @file){
          Fedit.stub(:insert, true, @file){
            assert(Change.apply(change, @ctx))
          }
        }
      }
    }
  end

  def test_apply_replace
    change = { 'edit' => '/foo', 'regex' => '/bob/', 'value' => 'bar' }

    mock = Minitest::Mock.new
    mock.expect(:=~, false, [Regexp.new(Regexp.quote('bar'))])

    assert_args = ->(file, regex, value){
      assert_equal(File.join(@ctx.root, @file), file)
      assert_equal('/bob/', regex)
      assert_equal('bar', value)
      true
    }

    Change.stub(:puts, nil){
      File.stub(:exist?, true, @file){
        File.stub(:binread, mock, @file){
          Fedit.stub(:replace, assert_args){
            assert(Change.apply(change, @ctx))
          }
        }
      }
    }

    assert_mock(mock)
  end

  def change_insert_helper(change, offset)
    mock = Minitest::Mock.new
    mock.expect(:=~, false, [Regexp.new(Regexp.quote('bar'))])

    assert_args = ->(file, values, opts){
      assert_equal(File.join(@ctx.root, @file), file)
      assert_equal(['bar'], values)
      assert_equal('/bob/', opts[:regex])
      opts[:offset] ? assert_equal(offset, opts[:offset]) : assert_nil(opts[:offset])
      true
    }

    Change.stub(:puts, nil){
      File.stub(:exist?, true, @file){
        File.stub(:binread, mock, @file){
          Fedit.stub(:insert, assert_args){
            assert(Change.apply(change, @ctx))
          }
        }
      }
    }

    assert_mock(mock)
  end

  def test_apply_insert
    change = { 'edit' => '/foo', 'append' => 'after', 'value' => 'bar', 'regex' => '/bob/' }
    change_insert_helper(change, 1)
    change['append'] = 'before'
    change_insert_helper(change, 0)
    change['append'] = true
    change_insert_helper(change, nil)
  end

  def test_apply_append
    change = { 'edit' => '/foo', 'append' => true, 'value' => 'bar' }

    mock = Minitest::Mock.new
    mock.expect(:=~, false, [Regexp.new(Regexp.quote('bar'))])

    assert_args = ->(file, values, opts){
      assert_equal(File.join(@ctx.root, @file), file)
      assert_equal(['bar'], values)
      assert_nil(opts[:regex])
      assert_nil(opts[:offset])
      true
    }

    Change.stub(:puts, nil){
      File.stub(:exist?, true, @file){
        File.stub(:binread, mock, @file){
          Fedit.stub(:insert, assert_args){
            assert(Change.apply(change, @ctx))
          }
        }
      }
    }

    assert_mock(mock)
  end
end

class TestRedirect < Minitest::Test

  def setup
    @ctx = OpenStruct.new({ root: '/de' })
  end

  def test_reusing_change_multiple_times
    change = {'exec' => "touch /foo"}
    ctx = OpenStruct.new({ root: '/build' })
    assert_equal({'exec' => "touch /build/foo"}, Change.redirect(change, ctx, Change.keys))
    ctx = OpenStruct.new({ root: '/base' })
    assert_equal({'exec' => "touch /base/foo"}, Change.redirect(change, ctx, Change.keys))
  end

  def test_redirect_with_relative_root
    change = {'exec' => "touch /foo"}
    ctx = OpenStruct.new({ root: '.' })
    assert_equal({'exec' => "touch ./foo"}, Change.redirect(change, ctx, Change.keys))
  end

  def test_redirect_with_exec_multi
    change = {'exec' => "touch //foo && echo '/foo' > /foo; tee /foo2 /foo3"}
    assert_equal({'exec' => "touch /foo && echo '/foo' > /de/foo; tee /de/foo2 /de/foo3"},
      Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_exec_combo
    change = {'exec' => "touch //foo && echo '/foo' > /foo"}
    assert_equal({'exec' => "touch /foo && echo '/foo' > /de/foo"}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_exec_host
    change = {'exec' => 'touch //foo'}
    assert_equal({'exec' => 'touch /foo'}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_exec
    change = {'exec' => 'touch /foo'}
    assert_equal({'exec' => 'touch /de/foo'}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_bogus
    change = {'bogus' => '/foo'}
    assert_raises(ArgumentError){Change.redirect(change, @ctx, Change.keys)}
  end

  def test_redirect_with_resolve_host
    change = {'resolve' => '//foo'}
    assert_equal({'resolve' => '/foo'}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_resolve
    change = {'resolve' => '/foo'}
    assert_equal({'resolve' => '/de/foo'}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_edit_host
    change = {'edit' => '//foo'}
    assert_equal({'edit' => '/foo'}, Change.redirect(change, @ctx, Change.keys))
  end

  def test_redirect_with_edit
    change = {'edit' => '/foo'}
    assert_equal({'edit' => '/de/foo'}, Change.redirect(change, @ctx, Change.keys))
  end
end

# vim: ft=ruby:ts=2:sw=2:sts=2
