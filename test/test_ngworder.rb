# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require_relative "../lib/ngworder"

class NgworderTest < Minitest::Test
  def run_cli(rule_text, input_text)
    rules_file = Tempfile.new("ngworder_rules")
    input_file = Tempfile.new("ngworder_input")

    rules_file.write(rule_text)
    rules_file.flush

    input_file.write(input_text)
    input_file.flush

    code = nil
    out, err = capture_io do
      code = Ngworder::CLI.run(["--rule=#{rules_file.path}", input_file.path])
    end

    [code, out, err, input_file.path]
  ensure
    rules_file.close!
    input_file.close!
  end

  def test_literal_with_exclusion
    code, out, _err, path = run_cli("ユーザ !ユーザー\n", "ユーザ ユーザー\n")

    lines = out.lines
    assert_equal 1, lines.length
    assert_match(/#{Regexp.escape(path)}:1:\d+\s+ユーザ\s+NG:ユーザ/, lines.first)
    assert_equal 1, code
  end

  def test_regex_match
    code, out, _err, path = run_cli("/ab+c/\n", "abbbc\n")

    assert_match(/#{Regexp.escape(path)}:1:1\s+abbbc\s+NG:\/ab\+c\//, out)
    assert_equal 1, code
  end

  def test_escape_hash_literal
    code, out, _err, path = run_cli("\\#タグ\n", "#タグ\n")

    assert_match(/#{Regexp.escape(path)}:1:1\s+#タグ\s+NG:\\#タグ/, out)
    assert_equal 1, code
  end

  def test_exclude_overlap
    code, out, _err, path = run_cli("foo !foobar\n", "foobar foo\n")

    lines = out.lines
    assert_equal 1, lines.length
    assert_match(/#{Regexp.escape(path)}:1:\d+\s+foo\s+NG:foo/, lines.first)
    assert_equal 1, code
  end
end
