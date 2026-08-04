require 'base64'
require 'liquid'
require 'json'

module SubstituteFilter
  def substitute(input, params = {})
    input.gsub(/%\{(\w+)\}/) { |_match| params[Regexp.last_match(1)] }
  end
end

file_system = ARGV[2] ? Liquid::LocalFileSystem.new(ARGV[2]) : Liquid::BlankFileSystem.new

environment =
  Liquid::Environment.build(file_system: file_system) do |env|
    env.register_filter(SubstituteFilter)
  end

context = Liquid::Context.build(environments: JSON.parse(ARGV[1]), environment: environment)
context.add_filters(SubstituteFilter)

puts Liquid::Template.parse(ARGV[0], environment: environment).render(context)
