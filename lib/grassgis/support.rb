module GrassGis
  module Support
    module_function

    def unindent(text, indent = nil)
      text = text.gsub(/\t/, ' '*8)
      mx = text.scan(/^ *[^\n\r]/)
               .flatten
               .map{ |s| s[-1,1]==' ' ? nil : (s.size-1) }
               .compact.min
      if mx && mx>0
        text.gsub!(/^ {1,#{mx}}/, "")
      end
      lines = text.split(/\r?\n/)
      if lines.first.strip.empty? || lines.last.strip.empty?
        lines.shift while lines.first.strip.empty?
        lines.pop while lines.last.strip.empty?
      end
      if indent
        indent = ' ' * indent if indent.kind_of?(Numeric)
        lines = lines.map { |line| "#{indent}#{line}" }
      end
      lines.join("\n")
    end
  end
end
