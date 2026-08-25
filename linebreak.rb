#!/usr/bin/ruby -w

# Return safe physical breakpoints in compact Bash produced by rollup.rb. Each
# entry contains the end of the current line, the start of the next, and any
# continuation to append. A differing end/start replaces an ordinary semicolon
# with a newline.

def breakpoints(text)
  points = []
  quoted = []
  i = 0

  while i < text.length
    ch = text[i]

    if ch == '\\'
      i += 2
      next
    end

    if ch == '"' || ch == "'"
      start = i
      quote = ch
      points << [i, i, '\\'] if i > 0 && text[i - 1] != ' '
      i += 1
      while i < text.length
        if quote == '"' && text[i] == '\\'
          i += 2
        elsif text[i] == quote
          i += 1
          break
        else
          i += 1
        end
      end
      quoted << (start...i)
      points << [i, i, '\\'] if text[i] && text[i] != ' '
      next
    end

    if text[i, 3] == ';;&'
      points << [i + 3, i + 3, '']
      i += 3
      next
    elsif text[i, 2] == ';;' || text[i, 2] == ';&'
      points << [i, i, '']
      points << [i + 2, i + 2, '']
      i += 2
      next
    elsif text[i, 2] == '&&' || text[i, 2] == '||'
      points << [i, i, '\\'] if i > 0 && text[i - 1] != ' '
      points << [i + 2, i + 2, '']
      i += 2
      next
    end

    if ch == ';'
      points << [i, i + 1, '']
    elsif ch == ' '
      points << [i + 1, i + 1, '\\']
    elsif ch == '|'
      points << [i + 1, i + 1, '\\']
    elsif ch == '('
      if (i > 0 && text[i - 1] == '=') ||
          (i > 1 && text[i - 2, 2] == '+=')
        points << [i, i, '\\']
        points << [i + 1, i + 1, '\\']
      end
    elsif ch == ')' && text[i + 1] && text[i + 1] !~ /[ ;)]/
      points << [i + 1, i + 1, '\\']
    elsif ch =~ /[[:alpha:]_]/
      j = i + 1
      j += 1 while text[j] && text[j] =~ /[[:alnum:]_]/
      if text[j, 2] == '()' || text[j] == '=' || text[j, 2] == '+='
        points << [j, j, '\\']
      end
      i = j
      next
    end

    i += 1
  end

  # A case pattern closes at the first ')' after 'case ... in ' or ';;'.
  case_pat = /(?:\bcase [^;]* in |;;)[^;]*?\)/
  text.to_enum(:scan, case_pat).each {
    start = Regexp.last_match.begin(0)
    pos = Regexp.last_match.end(0)
    next if quoted.any? { |range| range.cover?(start) || range.cover?(pos - 1) }
    points << [pos, pos, '']
  }

  points.sort_by { |left,right| [right, left] }.uniq
end

# Splitting an opaque atom is only allowed when that atom cannot fit on a line
# by itself. Single-quoted strings have no safe continuation form.
def split_atom(text, offset, max_len)
  limit = offset + max_len - 1

  if text[offset] =~ /[[:alnum:]_]/
    finish = offset + 1
    finish += 1 while text[finish] && text[finish] =~ /[[:alnum:]_]/
    return limit if finish - offset >= max_len && limit < finish
  elsif text[offset] == '"'
    finish = offset + 1
    escape = false
    while finish < text.length
      ch = text[finish]
      if escape
        escape = false
      elsif ch == '\\'
        escape = true
      elsif ch == '"'
        break
      end
      finish += 1
    end
    if finish - offset >= max_len && limit < finish
      limit -= 1 while limit > offset && text[limit - 1] == '\\'
      return limit if limit > offset
    end
  end

  nil
end

def wrap_line(text, max_len)
  points = breakpoints(text)
  lines = []
  offset = 0

  while text.length - offset > max_len
    fitting = points.select { |left,right,cont|
      left > offset && right > offset &&
        left - offset + cont.length <= max_len
    }
    point = fitting.max_by { |left,right,cont|
      [right, left, cont.empty? ? 1 : 0]
    }

    unless point
      if cut = split_atom(text, offset, max_len)
        lines << text[offset...cut] + '\\'
        offset = cut
        next
      end

      point = points.find { |left,right| left > offset && right > offset }
      unless point
        warn "No safe breakpoint in line longer than #{max_len} characters"
        lines << text[offset..]
        return lines
      end
      warn "No safe breakpoint before column #{max_len}"
    end

    left, right, cont = point
    lines << text[offset...left] + cont
    offset = right
  end

  lines << text[offset..] unless text[offset..].empty?
  lines
end

max_lines = nil
while ARGV[0]&.start_with?('--')
  case ARGV.shift
  when '--max-lines'
    max_lines = Integer(ARGV.shift)
  else
    raise "Unknown option"
  end
end

max_len = Integer(ARGV.shift)
raise "Width must be greater than 1" unless max_len > 1

if infile = ARGV.shift
  f = File.open infile
  script = f.read
else
  script = STDIN.read
end

if outfile = ARGV.shift
  output = File.open outfile, 'w'
else
  output = STDOUT
end

script.gsub!(/\r\n?/, "\n")
lines = []
code_lines = 0

script.each_line(chomp: true) { |line|
  wrapped = line.start_with?('#') ? [line] : wrap_line(line, max_len)
  lines.concat wrapped
  code_lines += wrapped.length unless line.start_with?('#')
}

if max_lines && code_lines > max_lines
  raise "Wrapped to #{code_lines} lines, exceeds #{max_lines}"
end

output.puts lines
