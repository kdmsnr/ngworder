# frozen_string_literal: true

require "optparse"
require "tempfile"
require_relative "ngworder/version"

module Ngworder
  Rule = Struct.new(:matcher, :label, :excludes)
  Matcher = Struct.new(:type, :pattern, :label)

  module Parser
    module_function

    def strip_comment(line)
      out = +""
      escaped = false

      line.each_char do |ch|
        if escaped
          out << ch
          escaped = false
          next
        end

        if ch == '\\'
          escaped = true
          out << ch
          next
        end

        break if ch == "#"

        out << ch
      end

      out
    end

    def split_unescaped_bang(line)
      parts = []
      current = +""
      escaped = false

      line.each_char do |ch|
        if escaped
          current << ch
          escaped = false
          next
        end

        if ch == '\\'
          escaped = true
          current << ch
          next
        end

        if ch == "!"
          parts << current
          current = +""
          next
        end

        current << ch
      end

      parts << current
      parts
    end

    def unescape_token(str)
      out = +""
      i = 0

      while i < str.length
        ch = str[i]

        if ch == '\\' && i + 1 < str.length
          nxt = str[i + 1]
          if ['\\', '/', '#', '!'].include?(nxt)
            out << nxt
            i += 2
            next
          end
        end

        out << ch
        i += 1
      end

      out
    end

    def unescaped_delim?(str, index)
      backslashes = 0
      i = index - 1
      while i >= 0 && str[i] == '\\'
        backslashes += 1
        i -= 1
      end
      backslashes.even?
    end

    def parse_matcher(raw, trim: :both)
      trimmed = case trim
                when :right
                  raw.rstrip
                when :none
                  raw
                else
                  raw.strip
                end
      return nil if trimmed.empty?

      if trimmed.start_with?("/") && trimmed.length >= 2 && trimmed.end_with?("/")
        return nil unless unescaped_delim?(trimmed, trimmed.length - 1)

        body = trimmed[1..-2]
        pattern = Regexp.new(unescape_token(body))
        return Matcher.new(:regex, pattern, trimmed)
      end

      literal = unescape_token(trimmed)
      Matcher.new(:literal, literal, trimmed)
    end

    def build_rules(path)
      rules = []

      File.readlines(path, chomp: true).each do |line|
        content = strip_comment(line)
        next if content.strip.empty?

        parts = split_unescaped_bang(content)
        base = parse_matcher(parts.shift || "", trim: :right)
        next unless base

        excludes = parts.map { |part| parse_matcher(part, trim: :both) }.compact
        rules << Rule.new(base, base.label, excludes)
      end

      rules
    end
  end

  module MatcherEngine
    module_function

    def match_spans(line, matcher)
      spans = []

      if matcher.type == :regex
        line.scan(matcher.pattern) do
          text = Regexp.last_match(0)
          next if text.nil? || text.empty?

          start_idx = Regexp.last_match.begin(0)
          end_idx = Regexp.last_match.end(0)
          spans << [start_idx, end_idx, text]
        end
      else
        needle = matcher.pattern
        return spans if needle.empty?

        start_idx = 0
        while (found = line.index(needle, start_idx))
          spans << [found, found + needle.length, needle]
          start_idx = found + 1
        end
      end

      spans
    end

    def excluded?(match_span, exclude_spans)
      match_start, match_end = match_span[0], match_span[1]

      exclude_spans.any? do |spans|
        spans.any? do |span|
          span_start, span_end = span[0], span[1]
          span_start < match_end && span_end > match_start
        end
      end
    end
  end

  module RgBackend
    module_function

    def available?
      system("rg", "--version", out: File::NULL, err: File::NULL)
    end

    def prefilter_lines(files, rules)
      literals = rules.map { |rule| rule.matcher.pattern }.uniq
      return {} if literals.empty?

      Tempfile.create("ngworder_rg") do |tmp|
        literals.each { |literal| tmp.puts Regexp.escape(literal) }
        tmp.flush

        cmd = ["rg", "--line-number", "--with-filename", "--no-heading", "--color=never", "-f", tmp.path, "--"] + files
        results = Hash.new { |hash, key| hash[key] = [] }

        IO.popen(cmd, "r") do |io|
          io.each_line do |line|
            path, line_no, content = line.chomp.split(":", 3)
            next unless path && line_no

            results[path] << [line_no.to_i, content || ""]
          end
        end

        results
      end
    rescue Errno::ENOENT
      nil
    end
  end

  class CLI
    def self.run(argv)
      options = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: ngworder [--rule=NGWORDS.txt] <files...>"
        opts.on("--rule=PATH", "Rules file path (default: NGWORDS.txt)") { |value| options[:rule] = value }
        opts.on("--rg", "Use ripgrep for literal-only prefiltering") { options[:rg] = true }
        opts.on("-h", "--help", "Show help") do
          puts opts
          return 0
        end
      end.parse!(argv)

      rule_path = options[:rule]
      rule_path = "NGWORDS.txt" if rule_path.nil? || rule_path.strip.empty?

      if argv.empty?
        warn "No input files provided"
        return 2
      end

      unless File.file?(rule_path)
        warn "Rules file not found: #{rule_path}"
        return 2
      end

      rules = Parser.build_rules(rule_path)
      warn "No rules loaded from #{rule_path}" if rules.empty?

      found = false

      argv.each do |path|
        warn "Skip missing file: #{path}" unless File.file?(path)
      end

      existing_files = argv.select { |path| File.file?(path) }

      literal_rules, regex_rules = rules.partition { |rule| rule.matcher.type == :literal }

      rg_enabled = options[:rg] && RgBackend.available?
      warn "rg not found; falling back to Ruby scan" if options[:rg] && !rg_enabled

      rg_lines = if rg_enabled && !literal_rules.empty?
                   RgBackend.prefilter_lines(existing_files, literal_rules)
                 else
                   nil
                 end
      rg_lines = nil if rg_lines.nil?

      existing_files.each do |path|
        if rg_lines && regex_rules.empty?
          candidates = rg_lines[path]
          next if candidates.nil? || candidates.empty?

          candidates.each do |line_no, line|
            literal_rules.each do |rule|
              matches = MatcherEngine.match_spans(line, rule.matcher)
              next if matches.empty?

              exclude_spans = rule.excludes.map { |ex| MatcherEngine.match_spans(line, ex) }

              matches.each do |span|
                next if MatcherEngine.excluded?(span, exclude_spans)

                found = true
                col_no = span[0] + 1
                puts "#{path}:#{line_no}:#{col_no}  #{span[2]}  NG:#{rule.label}"
              end
            end
          end
          next
        end

        candidate_lines = rg_lines ? rg_lines[path] : nil
        candidate_set = if candidate_lines
                          candidate_lines.each_with_object({}) { |(line_no, _line), acc| acc[line_no] = true }
                        else
                          nil
                        end

        File.readlines(path, chomp: true).each_with_index do |line, idx|
          line_no = idx + 1

          regex_rules.each do |rule|
            matches = MatcherEngine.match_spans(line, rule.matcher)
            next if matches.empty?

            exclude_spans = rule.excludes.map { |ex| MatcherEngine.match_spans(line, ex) }

            matches.each do |span|
              next if MatcherEngine.excluded?(span, exclude_spans)

              found = true
              col_no = span[0] + 1
              puts "#{path}:#{line_no}:#{col_no}  #{span[2]}  NG:#{rule.label}"
            end
          end

          next if candidate_set && !candidate_set.key?(line_no)

          literal_rules.each do |rule|
            matches = MatcherEngine.match_spans(line, rule.matcher)
            next if matches.empty?

            exclude_spans = rule.excludes.map { |ex| MatcherEngine.match_spans(line, ex) }

            matches.each do |span|
              next if MatcherEngine.excluded?(span, exclude_spans)

              found = true
              col_no = span[0] + 1
              puts "#{path}:#{line_no}:#{col_no}  #{span[2]}  NG:#{rule.label}"
            end
          end
        end
      end

      found ? 1 : 0
    end
  end
end
