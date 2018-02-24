require 'benchmark/ips'

def first
  x = []
  v = 3
  b = "#{v} of heart"
  x << b
end

def second
  x = []
  v = 3
  x << "#{v} of heart"
end

Benchmark.ips do |x|
    x.report('first')                 { first }
    x.report('second')            { second }
    x.compare!
  end

#upcase!
# def upcase_bang
#   x = 'foobar'.upcase!
# end

# def upcase_normal
#   x = 'foobar'.upcase
# end

# Benchmark.ips do |x|
#   x.report('Upcase Bang')                 { upcase_bang }
#   x.report('Upcase Normal')            { upcase_normal }
#   x.compare!
# end

#upcase

# # 2 + 1 = 3 object
# def slow_plus
#   'foo' + 'bar'
# end

# # 2 + 1 = 3 object
# def slow_concat
#   'foo'.concat 'bar'
# end

# # 2 + 1 = 3 object
# def slow_append
#   'foo' << 'bar'
# end

# # 1 object
# def fast
#   'foo' 'bar'
# end

# def fast_interpolation
#   "#{'foo'}#{'bar'}"
# end

# Benchmark.ips do |x|
#   x.report('String#+')                 { slow_plus }
#   x.report('String#concat')            { slow_concat }
#   x.report('String#append')            { slow_append }
#   x.report('"foo" "bar"')              { fast }
#   x.report('"#{\'foo\'}#{\'bar\'}"')   { fast_interpolation }
#   x.compare!
# end