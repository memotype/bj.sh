#!/usr/bin/ruby -w

require 'securerandom'


# Regexes to save and replace literals (strings, escaped semicolons, etc)
lits_re = [
  /(?<!\\)"(?:[^"\\]|\\.)*"/,
  /(?<!\\)'[^']*'/,
  /\\;/
]

# List of keywords that shouldn't have semicolons after them
ns_kws = [
  'if',
  'then',
  'elif',
  'else',
  'while',
  'until',
  'do',
  'in'
]

# Regexes to further transform the script, and their replacements
trans_re = [
  [/: ENDBJ(?:.|\n)*/,                ''],
  [/^[[:blank:]]*:[[:blank:]].*\n/,   ''],
  [/: :.*\n/,                         ''],
  [/^[[:blank:]]*#.*\n/,              ''],
  [/#.*\n/,                           ''],
  [/\\\n/,                            ''],
  [/\n+[[:blank:]]*\n*/,              ';'],
  [/[[:blank:]]*;[[:blank:]]*/,       ';'],
  [/[[:blank:]]+/,                    ' '],
  [/ {;/,                             '{ '],
  [/ \(;/,                            '('],
  [/ ?&& ?/,                          '&&'],
  [/;case ([^ ]*) in; *([^\)]*\)) */, ';case \1 in \2'],
  [/ ?;;;* ?/,                        ';;'],
  [/(;;[^;\(]*\)) *;? */,             '\1'],
  [/ *\|\| */,                        '||'],
  [/ *</,                             '<'],

  [/^;/,                              ''],
  [/;$/,                              ''],
]

ns_kws.each { |kw|
  #           [/;if;/,      ';if ']  etc...
  trans_re << [/;(#{kw});/, ';\1 ']
}

wrap_len = nil
max_lines = nil

while ARGV[0]&.start_with?('--')
  case ARGV.shift
  when '--wrap'
    wrap_len = Integer(ARGV.shift)
  when '--max-lines'
    max_lines = Integer(ARGV.shift)
  else
    raise "Unknown option"
  end
end

if infile = ARGV.shift
  f = File.open infile
  script = f.read
else
  script = STDIN.read
end

# Normalize CRLF to LF for consistent regex matching.
script.gsub!(/\r\n?/, "\n")

if outfile = ARGV.shift
  output = File.open outfile, 'w'
else
  output = STDOUT
end

# Array of replaced literals. We use an array so we can be sure to replace
# them back in the right order, in case there are 'nested' literals.
lits = []

lits_re.each { |re|
  script.gsub!(re) { |str|
    repl = SecureRandom.hex(16)
    lits.unshift [repl, str]
    next repl
  }
}

trans_re.each { |re,repl|
  script.gsub! re, repl
}

def merge_lines(lines, max_len)
  find_break = lambda do |text, limit, max_soft|
    in_squote = false
    in_dquote = false
    escape = false
    last_soft = nil
    last_soft_fit = nil
    last_hard = nil
    i = 0
    while i < text.length && i < limit
      ch = text[i]
      if escape
        escape = false
        i += 1
        next
      end
      if in_dquote
        if ch == '\\'
          escape = true
        elsif ch == '"'
          in_dquote = false
        end
        i += 1
        next
      end
      if in_squote
        in_squote = false if ch == "'"
        i += 1
        next
      end

      if ch == '"' && text[i - 1] != '\\'
        in_dquote = true
      elsif ch == "'"
        in_squote = true
      elsif ch == ';'
        nxt = text[i + 1]
        prv = i > 0 ? text[i - 1] : nil
        if prv == ';'
          last_hard = i + 1
        elsif nxt != ';'
          last_hard = i + 1
        end
      elsif (ch == '&' || ch == '|') && i > 0 && text[i - 1] == ch
        last_hard = i + 1
      elsif ch == ' '
        next_is_in = text[i + 1, 3] == 'in '
        has_case = text[0..i].include?('case ')
        has_in = text[0..i].include?(' in ')
        end_is_in = text[0..i].end_with?(' in ') || text[0..i].end_with?(' in')
        if !(next_is_in && has_case) && !(end_is_in && has_case) &&
            !(has_case && !has_in)
          last_soft = i + 1
          last_soft_fit = last_soft if last_soft <= max_soft
        end
      end
      i += 1
    end
    [last_hard, last_soft_fit || last_soft]
  end

  merged = []
  cur = lines[0]
  idx = 1
  while cur && idx < lines.length
    cur_base = cur.end_with?('\\') ? cur[0..-2] : cur
    nxt = lines[idx]
    join = cur_base + nxt
    if join.length <= max_len
      cur = join
      idx += 1
      next
    end

    if cur.end_with?(' in \\')
      if cur_base.length + nxt.length <= max_len
        cur = cur_base + nxt
        idx += 1
        next
      end
    end

    if cur.end_with?(' in \\')
      m = nxt.match(/\A[^)]*\)/)
      if m
        prefix = m[0]
        if cur_base.length + prefix.length <= max_len
          merged << (cur_base + prefix)
          cur = nxt[prefix.length..]
          idx += 1
          next
        end
      end
    end

    if nxt.start_with?('case ')
      in_idx = nxt.index(' in ')
      if in_idx
        prefix_len = in_idx + 4
        if cur_base.length + prefix_len + 1 <= max_len
          merged << (cur_base + nxt[0...prefix_len] + '\\')
          cur = nxt[prefix_len..]
          idx += 1
          next
        end
      end
    end

    remain = max_len - cur_base.length
    if remain > 5
      max_soft = max_len - cur_base.length - 1
      hard_idx, soft_idx = find_break.call(nxt, remain, max_soft)
      best_kind = nil
      best_len = nil

      if hard_idx && (cur_base.length + hard_idx <= max_len)
        best_kind = :hard
        best_len = hard_idx
      end
      if soft_idx && (cur_base.length + soft_idx + 1 <= max_len)
        soft_len = soft_idx + 1
        if !best_len || soft_len > best_len
          best_kind = :soft
          best_len = soft_idx
        end
      end

      if best_kind == :hard
        merged << (cur_base + nxt[0...best_len])
        cur = nxt[best_len..]
        idx += 1
        next
      elsif best_kind == :soft
        merged << (cur_base + nxt[0...best_len] + '\\')
        cur = nxt[best_len..]
        idx += 1
        next
      end
    end

    merged << cur
    cur = nxt
    idx += 1
  end

  merged << cur if cur
  merged
end

def wrap_lines(text, max_len)
  lines = []
  line = +''
  last_soft = nil
  last_hard = nil
  in_squote = false
  in_dquote = false
  escape = false

  text.each_char.with_index do |ch, idx|
    line << ch

    if escape
      escape = false
    elsif in_dquote
      if ch == '\\'
        escape = true
      elsif ch == '"'
        in_dquote = false
      end
    elsif in_squote
      in_squote = false if ch == "'"
    else
      if ch == '"' && text[idx - 1] != '\\'
        in_dquote = true
      elsif ch == "'"
        in_squote = true
      end

      if ch == ';'
        next_ch = text[idx + 1]
        prev_ch = text[idx - 1]
        if next_ch == ';' || prev_ch == ';'
          # part of ';;' handled when second ';' arrives
        else
          last_hard = line.length
        end
      elsif ch == '&' || ch == '|'
        if idx > 0 && text[idx - 1] == ch
          last_hard = line.length
        end
      elsif ch == ' '
        next_ch = text[idx + 1]
        next_is_in = text[idx + 1, 3] == 'in '
        has_case = line.include?('case ')
        has_in = line.include?(' in ')
        end_is_in = line.end_with?(' in ') || line.end_with?(' in')
        if next_ch != ';' && next_ch != '&' && next_ch != '|'
          last_soft = line.length unless (next_is_in && has_case) ||
            (end_is_in && has_case) || (has_case && !has_in)
        end
      elsif line.end_with?(';;')
        last_hard = line.length
      end
    end

    next unless line.length > max_len

    if last_hard
      lines << line[0...last_hard]
      line = line[last_hard..]
    elsif last_soft
      cut = last_soft
      lines << (line[0...cut] + '\\')
      line = line[cut..]
    else
      raise "No safe wrap point within #{max_len} chars"
    end

    last_soft = nil
    last_hard = nil
  end

  lines << line unless line.empty?
  merged = lines
  3.times do
    next_merged = merge_lines(merged, max_len)
    break if next_merged == merged
    merged = next_merged
  end
  merged
end

if wrap_len
  lits.each { |repl, str|
    script.gsub! repl, str
  }
  lines = wrap_lines(script, wrap_len)
  if max_lines && lines.length > max_lines
    raise "Wrapped to #{lines.length} lines, exceeds #{max_lines}"
  end
  script = lines.join("\n")
else
  lits.each { |repl, str|
    script.gsub! repl, str
  }
end

output.puts ("# (C) Isaac Freeman (memotype@gmail.com). " \
  + "See https://github.com/memotype/bj.sh")
output.puts script
